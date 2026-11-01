#!/usr/bin/env node
/**
 * Audit one packaged Linux Desktop artifact for the fixed, offline SCNet bundle.
 *
 * The parent process extracts a deb when needed and then re-executes this file with
 * the packaged Electron binary. Electron's Node mode supplies ASAR-aware fs calls,
 * so the audit reads the exact archived runtime without downloading an asar tool.
 */

import { createHash } from 'node:crypto'
import {
  existsSync,
  lstatSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { basename, dirname, join, relative, resolve, sep } from 'node:path'
import { spawnSync } from 'node:child_process'

const DEFAULT_VERSION = '0.6.13'
const PACKAGE_NAME = 'dsh-scnet'
const SKILL_NAME = 'scnet-hpc'
const DESCRIPTOR = 'desktop-packages.json'
const PACKAGE_DIR = 'desktop-packages'

function usage(message) {
  if (message) console.error(`error: ${message}`)
  console.error(`usage:
  node ci/scnet-release-audit.mjs --deb <file.deb> [--package-set <dir>] [--expected-version <version>] [--output <evidence.json>] [--require-setup true]
  node ci/scnet-release-audit.mjs --app <linux-unpacked> [--package-set <dir>] [--expected-version <version>] [--output <evidence.json>] [--require-setup true]`)
  process.exit(message ? 2 : 0)
}

function parseArgs(argv) {
  const options = {}
  for (let index = 0; index < argv.length; index += 1) {
    const name = argv[index]
    if (name === '--help' || name === '-h') usage()
    if (!name?.startsWith('--')) usage(`unexpected argument ${String(name)}`)
    const value = argv[index + 1]
    if (value === undefined || value.startsWith('--')) usage(`${name} requires a value`)
    options[name.slice(2)] = value
    index += 1
  }
  return options
}

function record(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function json(path, label) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch (error) {
    throw new Error(`${label}: cannot read ${path}: ${String(error)}`)
  }
}

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex')
}

function targetSha256(path) {
  return lstatSync(path).isDirectory() ? sha256(join(path, 'dsh', 'desktop-runtime.json')) : sha256(path)
}

function sha512Integrity(path) {
  return `sha512-${createHash('sha512').update(readFileSync(path)).digest('base64')}`
}

function normalize(path) {
  return path.split(sep).join('/')
}

function walk(root) {
  const files = []
  const visit = (directory) => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name)
      if (entry.isDirectory()) visit(path)
      else if (entry.isFile()) files.push(path)
      else throw new Error(`unsupported package entry: ${normalize(relative(root, path))}`)
    }
  }
  visit(root)
  return files.sort()
}

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function packageSetEvidence(path, expectedVersion) {
  if (path === undefined) return { checked: false }
  const root = statSync(path).isDirectory() ? path : dirname(path)
  const descriptorPath = statSync(path).isDirectory() ? join(path, DESCRIPTOR) : path
  const value = json(descriptorPath, 'package set')
  assert(record(value) && value.schemaVersion === 1 && Array.isArray(value.packages), 'package set: invalid descriptor')
  const matches = value.packages.filter(entry => record(entry) && entry.name === PACKAGE_NAME)
  assert(matches.length === 1, `package set: expected one ${PACKAGE_NAME} record`)
  const entry = matches[0]
  assert(entry.version === expectedVersion, `package set: expected ${PACKAGE_NAME}@${expectedVersion}, found ${String(entry.version)}`)
  assert(entry.license === 'MIT', `package set: expected ${PACKAGE_NAME} license MIT`)
  assert(typeof entry.integrity === 'string' && /^sha512-[A-Za-z0-9+/]+={0,2}$/u.test(entry.integrity),
    `package set: ${PACKAGE_NAME} has no valid SHA-512 integrity`)
  assert(typeof entry.file === 'string' && entry.file.endsWith('.tgz'), `package set: ${PACKAGE_NAME} has no tarball`)
  const tarball = join(root, PACKAGE_DIR, entry.file)
  assert(existsSync(tarball) && lstatSync(tarball).isFile(), `package set: missing ${entry.file}`)
  assert(statSync(tarball).size === entry.bytes, `package set: byte count differs for ${entry.file}`)
  assert(sha512Integrity(tarball) === entry.integrity, `package set: integrity differs for ${entry.file}`)
  return {
    checked: true,
    descriptor: realpathSync(descriptorPath),
    package: { name: entry.name, version: entry.version, license: entry.license, file: entry.file,
      bytes: entry.bytes, integrity: entry.integrity },
  }
}

function placeholder(value) {
  return /^(?:<.*>|\$\{.*\}|\$[A-Z_]+|\*+|x+|redacted|replace[-_ ]?me|your[-_]|example|dummy|test[-_])/iu.test(value)
}

function sensitiveContentFindings(path, text) {
  const findings = []
  if (/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/u.test(text)) {
    findings.push(`${path}: embedded private key`)
  }
  if (/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/u.test(text)) {
    findings.push(`${path}: JWT-like token`)
  }
  const credential = /(?:access[_-]?token|refresh[_-]?token|app[_-]?(?:id|secret)|client[_-]?secret|scnet_(?:openapi[_-]?)?(?:access[_-]?key|secret[_-]?key|ak|sk))\s*[:=]\s*(?:["']([^"'\r\n]{4,})["']|([A-Za-z0-9_./+=-]{8,})(?=\s*(?:$|#|\/\/)))/gimu
  for (const match of text.matchAll(credential)) {
    const value = (match[1] ?? match[2]).trim()
    if (!placeholder(value)) findings.push(`${path}: populated credential field ${match[0].split(/[:=]/u, 1)[0].trim()}`)
  }
  const urls = text.match(/https?:\/\/[^\s"'<>`)\]}]+/giu) ?? []
  for (const raw of urls) {
    let url
    try {
      url = new URL(raw.replace(/[.,;:]+$/u, ''))
    } catch {
      continue
    }
    const host = url.hostname.toLowerCase()
    const normalizedHost = host.replace(/^\[|\]$/gu, '')
    const octets = normalizedHost.split('.').map(value => Number(value))
    const privateIpv4 = octets.length === 4 && octets.every(Number.isInteger)
      && (octets[0] === 10 || octets[0] === 127 || (octets[0] === 100 && octets[1] >= 64 && octets[1] <= 127)
        || (octets[0] === 169 && octets[1] === 254) || (octets[0] === 192 && octets[1] === 168)
        || (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31))
    const privateIpv6 = /^(?:fc|fd|fe[89ab])/u.test(normalizedHost)
    const loopback = host === 'localhost' || normalizedHost === '::1'
      || (octets.length === 4 && octets[0] === 127)
    if (((privateIpv4 || privateIpv6) && !loopback)
      || /\.(?:internal|corp|lan|local)$/u.test(host) || url.username || url.password) {
      findings.push(`${path}: private or credentialed endpoint ${url.origin}`)
    }
  }
  return findings
}

function runtimeEvidence(appRoot, expectedVersion, requireSetup) {
  const resources = join(appRoot, 'resources')
  const archive = join(resources, 'app.asar')
  assert(existsSync(archive), `artifact: missing ${archive}`)
  const runtimeRoot = join(archive, 'dsh')
  const runtimeManifest = json(join(runtimeRoot, 'package.json'), 'runtime manifest')
  assert(record(runtimeManifest.dependencies), 'runtime manifest: dependencies are missing')
  assert(runtimeManifest.dependencies[PACKAGE_NAME] === expectedVersion,
    `runtime manifest: expected ${PACKAGE_NAME}@${expectedVersion}`)

  const bundleRoot = join(runtimeRoot, 'node_modules', PACKAGE_NAME)
  const bundleManifest = json(join(bundleRoot, 'package.json'), 'SCNet bundle manifest')
  assert(bundleManifest.name === PACKAGE_NAME && bundleManifest.version === expectedVersion,
    `SCNet bundle: expected ${PACKAGE_NAME}@${expectedVersion}`)
  assert(bundleManifest.license === 'MIT', 'SCNet bundle: expected MIT license')
  assert(record(bundleManifest.dsh) && record(bundleManifest.dsh.bundle)
    && bundleManifest.dsh.bundle.patch === './cordis.patch.yml', 'SCNet bundle: invalid DSH bundle metadata')

  const skillRoot = join(bundleRoot, 'skills', SKILL_NAME)
  assert(existsSync(join(bundleRoot, 'cordis.patch.yml')), 'SCNet bundle: cordis.patch.yml is missing')
  const callbackPath = join(bundleRoot, 'connector', 'callback.mjs')
  const connectorIndexPath = join(bundleRoot, 'connector', 'index.mjs')
  assert(existsSync(callbackPath), 'SCNet bundle: loopback callback listener is missing')
  assert(existsSync(connectorIndexPath), 'SCNet bundle: connector entrypoint is missing')
  assert(readFileSync(connectorIndexPath, 'utf8').includes('listenLoopbackCallback'),
    'SCNet bundle: loopback callback listener is not exported')
  assert(existsSync(join(skillRoot, 'SKILL.md')), `SCNet bundle: ${SKILL_NAME} Skill is missing`)
  assert(readFileSync(join(skillRoot, 'VERSION'), 'utf8').trim() === expectedVersion,
    `SCNet bundle: ${SKILL_NAME} VERSION does not match ${expectedVersion}`)
  const patch = readFileSync(join(bundleRoot, 'cordis.patch.yml'), 'utf8')
  assert(patch.includes('providerName: scnet-hpc') && patch.includes('name: dsh-scnet'),
    'SCNet bundle: cordis patch does not register the bundle and Skill provider')

  const descriptor = json(join(runtimeRoot, 'desktop-runtime.json'), 'runtime descriptor')
  assert(record(descriptor) && descriptor.schemaVersion === 1 && Array.isArray(descriptor.files)
    && Array.isArray(descriptor.sharedPackages), 'runtime descriptor: invalid schema')
  const shared = descriptor.sharedPackages.find(entry => record(entry) && entry.name === PACKAGE_NAME)
  assert(shared?.version === expectedVersion && shared.path === `node_modules/${PACKAGE_NAME}`,
    `runtime descriptor: missing ${PACKAGE_NAME}@${expectedVersion}`)
  const inventory = new Map(descriptor.files.map(entry => [entry.path, entry]))

  const files = walk(bundleRoot)
  const actualRuntimePaths = files.map(file => `node_modules/${PACKAGE_NAME}/${normalize(relative(bundleRoot, file))}`)
  const recordedRuntimePaths = descriptor.files
    .map(entry => entry.path)
    .filter(path => typeof path === 'string' && path.startsWith(`node_modules/${PACKAGE_NAME}/`))
  assert(JSON.stringify(recordedRuntimePaths) === JSON.stringify(actualRuntimePaths),
    `runtime descriptor: ${PACKAGE_NAME} file inventory differs from the archive`)
  const forbiddenPaths = []
  const sensitive = []
  let scannedTextFiles = 0
  for (const file of files) {
    const packagePath = normalize(relative(bundleRoot, file))
    const runtimePath = `node_modules/${PACKAGE_NAME}/${packagePath}`
    if (packagePath.split('/').includes('__pycache__') || packagePath.endsWith('.pyc')
      || packagePath.includes('/clusters/.cache/') || packagePath.startsWith('skills/scnet-hpc/clusters/.cache/')) {
      forbiddenPaths.push(packagePath)
    }
    const body = readFileSync(file)
    const entry = inventory.get(runtimePath)
    assert(record(entry) && entry.bytes === body.byteLength && entry.sha256 === createHash('sha256').update(body).digest('hex'),
      `runtime descriptor: integrity mismatch for ${runtimePath}`)
    if (body.byteLength <= 2 * 1024 * 1024 && !body.includes(0)) {
      scannedTextFiles += 1
      sensitive.push(...sensitiveContentFindings(packagePath, body.toString('utf8')))
    }
  }
  assert(forbiddenPaths.length === 0, `SCNet bundle: forbidden cache/generated paths: ${forbiddenPaths.join(', ')}`)
  assert(sensitive.length === 0, `SCNet bundle: sensitive content found:\n${sensitive.join('\n')}`)

  let setup = { checked: false }
  if (requireSetup) {
    const physicalBundle = join(resources, 'app.asar.unpacked', 'dsh', 'node_modules', PACKAGE_NAME)
    for (const archivedFile of files) {
      const physicalFile = join(physicalBundle, relative(bundleRoot, archivedFile))
      assert(existsSync(physicalFile) && sha256(physicalFile) === sha256(archivedFile),
        `SCNet setup: external file missing or changed: ${relative(bundleRoot, archivedFile)}`)
    }
    const script = join(physicalBundle, 'skills', SKILL_NAME, 'scripts', 'scnet.py')
    const help = spawnSync('python3', [script, '--help'], {
      env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' }, encoding: 'utf8', timeout: 15_000,
    })
    if (help.error) throw help.error
    assert(help.status === 0 && /usage:/iu.test(help.stdout),
      `SCNet setup: external Python could not load the packaged wizard: ${help.stderr}`)
    setup = { checked: true, physicalFiles: files.length, pythonHelp: true }
  }

  return {
    archive: 'resources/app.asar',
    runtimeRelease: descriptor.release?.version,
    package: { name: bundleManifest.name, version: bundleManifest.version, license: bundleManifest.license },
    skill: { name: SKILL_NAME, version: expectedVersion },
    loopbackCallback: { present: true, exported: true },
    setup,
    files: files.length,
    scannedTextFiles,
    forbiddenPaths: 0,
    sensitiveFindings: 0,
  }
}

function findAppRoot(extracted) {
  const candidates = []
  const visit = (directory, depth) => {
    if (depth > 5) return
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue
      const path = join(directory, entry.name)
      if (entry.name === 'resources' && existsSync(join(path, 'app.asar'))) candidates.push(dirname(path))
      else visit(path, depth + 1)
    }
  }
  visit(extracted, 0)
  assert(candidates.length === 1, `artifact: expected one app.asar, found ${candidates.length}`)
  return candidates[0]
}

function findLauncher(appRoot) {
  for (const name of ['DeepSeek Harness', 'deepseek-harness', 'electron']) {
    const candidate = join(appRoot, name)
    if (existsSync(candidate) && lstatSync(candidate).isFile()) return candidate
  }
  throw new Error(`artifact: cannot find Electron launcher under ${appRoot}`)
}

function runChild(options, appRoot, target) {
  const archive = join(appRoot, 'resources', 'app.asar')
  const runtime = lstatSync(archive).isDirectory() ? process.execPath : findLauncher(appRoot)
  const args = [
    ...(runtime === process.execPath ? [] : ['--expose-internals']),
    import.meta.filename,
    '--child-app', appRoot,
    '--expected-version', options['expected-version'] ?? DEFAULT_VERSION,
    '--target-kind', target.kind,
    '--target-path', target.path,
    '--target-sha256', target.sha256,
  ]
  if (options['package-set']) args.push('--package-set', resolve(options['package-set']))
  if (options.output) args.push('--output', resolve(options.output))
  if (options['require-setup'] !== undefined) args.push('--require-setup', options['require-setup'])
  const result = spawnSync(runtime, args, {
    env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' },
    stdio: 'inherit',
  })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`artifact: child audit exited ${String(result.status)}`)
}

function child(options) {
  const expectedVersion = options['expected-version'] ?? DEFAULT_VERSION
  const appRoot = resolve(options['child-app'])
  const packageSet = packageSetEvidence(options['package-set'], expectedVersion)
  const runtime = runtimeEvidence(appRoot, expectedVersion, options['require-setup'] === 'true')
  const evidence = {
    schemaVersion: 1,
    result: 'PASS',
    expectedBundle: `${PACKAGE_NAME}@${expectedVersion}`,
    target: {
      kind: options['target-kind'],
      path: options['target-path'],
      sha256: options['target-sha256'],
    },
    packageSet,
    runtime,
  }
  if (options.output) writeFileSync(options.output, `${JSON.stringify(evidence, undefined, 2)}\n`)
  console.log(`PASS: target SHA256 ${options['target-sha256']}`)
  console.log(`PASS: package set ${packageSet.checked ? 'integrity and MIT license verified' : 'not supplied'}`)
  console.log(`PASS: archived runtime contains ${PACKAGE_NAME}@${expectedVersion} and ${SKILL_NAME}`)
  console.log(`PASS: ${runtime.files} bundle files match the signed runtime descriptor`)
  console.log(`PASS: ${runtime.scannedTextFiles} text files contain no populated credentials or private endpoints`)
  console.log('PASS: no SCNet cache, __pycache__, or .pyc paths are present')
  if (runtime.setup.checked) console.log('PASS: unpacked SCNet files match the archive and external Python loads the wizard')
}

const options = parseArgs(process.argv.slice(2))
if (options['require-setup'] !== undefined && options['require-setup'] !== 'true') usage('--require-setup accepts only true')
try {
  if (options['child-app']) {
    child(options)
  } else {
    const hasDeb = options.deb !== undefined
    const hasApp = options.app !== undefined
    if (hasDeb === hasApp) usage('provide exactly one of --deb or --app')
    if (options['expected-version'] === '') usage('--expected-version cannot be empty')
    if (hasApp) {
      const appRoot = resolve(options.app)
      const archive = join(appRoot, 'resources', 'app.asar')
      assert(existsSync(archive), `artifact: missing ${archive}`)
      runChild(options, appRoot, { kind: 'app', path: realpathSync(appRoot), sha256: targetSha256(archive) })
    } else {
      const deb = realpathSync(options.deb)
      assert(deb.endsWith('.deb'), `artifact: expected a .deb file, found ${basename(deb)}`)
      const extracted = mkdtempSync(join(tmpdir(), 'dsh-scnet-release-audit-'))
      try {
        const unpack = spawnSync('dpkg-deb', ['-x', deb, extracted], { stdio: 'inherit' })
        if (unpack.error) throw unpack.error
        assert(unpack.status === 0, `artifact: dpkg-deb exited ${String(unpack.status)}`)
        runChild(options, findAppRoot(extracted), { kind: 'deb', path: deb, sha256: sha256(deb) })
      } finally {
        rmSync(extracted, { recursive: true, force: true })
      }
    }
  }
} catch (error) {
  console.error(`FAIL: ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
}

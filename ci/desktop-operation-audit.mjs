/** Exercise the shipped management producer, diagnostic parser and report Worker offline. */
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'
import { pathToFileURL } from 'node:url'
import { Worker } from 'node:worker_threads'

assert.ok(process.versions.electron, 'Run this audit through the packaged Electron in Node mode')
const resources = process.argv[2]
assert.ok(resources, 'Pass the installed application resources directory')
const runtime = join(resources, 'app.asar', 'dsh')
const runtimeRequire = createRequire(pathToFileURL(join(runtime, 'package.json')))
const { default: PluginManager } = runtimeRequire('@deepseek-ai/dsh-plugin-manager')
const { parsePluginOperationRecord } = runtimeRequire('@deepseek-ai/dsh-plugin-manager/diagnostic')
const { boot, initProfile, loadProfileDirectory, readProfilePatches, readProfileManifest } = runtimeRequire('@deepseek-ai/dsh-app-boot')
const directory = mkdtempSync(join(tmpdir(), 'desktop-operation-audit-'))
let context
let worker
try {
  const profileDir = join(directory, 'profile')
  const anchor = join(runtime, 'node_modules', '@deepseek-ai', 'dsh', 'package.json')
  initProfile(profileDir, ['core', 'extra'])
  for (const name of ['core', 'extra']) {
    const packageDir = join(profileDir, 'node_modules', name)
    mkdirSync(packageDir, { recursive: true })
    writeFileSync(join(packageDir, 'package.json'), JSON.stringify({ name, version: '1.0.0', dsh: { bundle: { patch: './cordis.patch.yml' } } }))
    writeFileSync(join(packageDir, 'cordis.patch.yml'), JSON.stringify([{ insert: name === 'core'
      ? [{ id: 'manager', name: 'cordis:manager' }] : [{ id: 'managed', name: './plugin.mjs' }] }]))
    writeFileSync(join(packageDir, 'plugin.mjs'), 'export function apply(ctx) { ctx.provide("operationAuditProbe", true) }\n')
  }
  const manifest = readProfileManifest('audit', profileDir)
  manifest.dependencies = { extra: '1.0.0' }
  writeFileSync(join(profileDir, 'package.json'), JSON.stringify(manifest))
  const config = join(profileDir, 'cordis.yml')
  writeFileSync(config, '[]\n')
  const profile = { name: 'audit', dir: profileDir, patchPath: join(profileDir, 'cordis.patch.yml'),
    installAnchor: anchor, cwd: directory, home: directory, overlays: [], telemetryDisabledEnv: undefined,
    startedBundles: loadProfileDirectory('audit', profileDir, anchor).layers.map(layer => layer.packageName) }
  context = await boot('audit', config, readProfilePatches('audit', profile), ctx => {
    ctx.provide('appReady', { onReady: listener => { listener(); return () => {} } })
    ctx.provide('profileContext', profile)
    ctx.loader.builtins.manager = PluginManager
  })
  const operations = []
  context.on('plugin-manager/operation', operation => { operations.push(operation) })
  const result = await context.pluginManager.setBundleEnabled('extra', false)
  assert.equal(result.changed, true)
  assert.equal(result.application, 'restart-required')
  assert.deepEqual(operations.map(operation => operation.phase), ['started', 'settled'])
  assert.equal(operations[0].id, operations[1].id)
  assert.equal(operations[1].target, 'extra')
  assert.ok(!readProfileManifest('audit', profileDir).dsh.profile.bundles.includes('extra'))
  const runId = randomUUID()
  const records = operations.map(operation => parsePluginOperationRecord({ runId, transportDropped: 0,
    operation: { ...operation, diagnostic: 'private-output-must-not-be-appended' }, credential: 'private-token' }))
  assert.ok(records.every(Boolean))
  assert.ok(!JSON.stringify(records).includes('private-'))
  await context.fiber.dispose(); context = undefined
  writeFileSync(join(directory, 'operations.jsonl'), records.map(record => JSON.stringify(record)).join('\n') + '\n')
  const reportPath = join(directory, 'crash.log')
  const basic = 'independently saved basic report\n'
  writeFileSync(reportPath, basic)
  const entry = join(resources, 'app.asar.unpacked', 'lib', 'operation-report-worker.js')
  assert.ok(existsSync(entry), 'The isolated Worker must be a physical packaged file')
  worker = new Worker(pathToFileURL(entry), { workerData: { reportPath, directory,
    limits: { bytes: 65536, recordBytes: 4096, records: 100, outputBytes: 65536 },
    journal: { dropped: 0, failed: 0, repairedSegments: 0, queuedBytes: 0, disabled: false } },
    resourceLimits: { maxOldGenerationSizeMb: 32, maxYoungGenerationSizeMb: 8, stackSizeMb: 2 } })
  let appended = false
  const deadline = setTimeout(() => { void worker.terminate() }, 5000)
  try {
    const exit = await new Promise((resolve, reject) => {
      worker.on('message', message => { appended = message === true })
      worker.once('error', reject); worker.once('exit', resolve)
    })
    assert.equal(exit, 0, 'The shipped report Worker must exit successfully')
    assert.equal(appended, true)
  } finally { clearTimeout(deadline) }
  const report = readFileSync(reportPath, 'utf8')
  assert.ok(report.startsWith(basic))
  assert.ok(report.includes('operation history collection complete'))
  assert.ok(!report.includes('private-'))
  const summary = JSON.parse(report.split('\n').find(line => line.startsWith('{')))
  assert.equal(summary.records.length, 2)
  assert.equal(summary.records[0].operation.phase, 'settled')
  assert.equal(summary.invalidRecords, 0)
  console.log('PASS: packaged plugin manager emits correlated persisted management facts')
  console.log('PASS: packaged diagnostic parser excludes raw private fields')
  console.log('PASS: shipped physical Worker preserves the basic report and appends complete history')
} finally {
  await worker?.terminate()
  await context?.fiber.dispose()
  rmSync(directory, { recursive: true, force: true })
}

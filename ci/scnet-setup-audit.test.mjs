import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { mkdirSync, mkdtempSync, writeFileSync, cpSync, unlinkSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'

function fixture(t, python = 'import argparse\nargparse.ArgumentParser().parse_args()\n') {
  const root = mkdtempSync(join(tmpdir(), 'scnet-audit-'))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  const runtime = join(root, 'resources/app.asar/dsh')
  const bundle = join(runtime, 'node_modules/dsh-scnet')
  const bodies = {
    'package.json': JSON.stringify({ name: 'dsh-scnet', version: '0.6.13', license: 'MIT', dsh: { bundle: { patch: './cordis.patch.yml' } } }),
    'cordis.patch.yml': 'name: dsh-scnet\nproviderName: scnet-hpc\n',
    'connector/callback.mjs': 'export function listenLoopbackCallback() {}\n',
    'connector/index.mjs': 'export { listenLoopbackCallback } from "./callback.mjs"\n',
    'skills/scnet-hpc/VERSION': '0.6.13\n',
    'skills/scnet-hpc/SKILL.md': '# Offline fixture\n',
    'skills/scnet-hpc/scripts/scnet.py': python,
  }
  for (const [path, content] of Object.entries(bodies)) {
    mkdirSync(join(bundle, path, '..'), { recursive: true }); writeFileSync(join(bundle, path), content)
  }
  writeFileSync(join(runtime, 'package.json'), JSON.stringify({ dependencies: { 'dsh-scnet': '0.6.13' } }))
  writeFileSync(join(runtime, 'desktop-runtime.json'), JSON.stringify({ schemaVersion: 1,
    sharedPackages: [{ name: 'dsh-scnet', version: '0.6.13', path: 'node_modules/dsh-scnet' }],
    files: Object.keys(bodies).sort().map(path => ({ path: `node_modules/dsh-scnet/${path}`,
      bytes: Buffer.byteLength(bodies[path]), sha256: createHash('sha256').update(bodies[path]).digest('hex') })),
  }))
  const unpacked = join(root, 'resources/app.asar.unpacked/dsh/node_modules/dsh-scnet')
  cpSync(bundle, unpacked, { recursive: true })
  const run = (required = true) => spawnSync(process.execPath, [new URL('./scnet-release-audit.mjs', import.meta.url).pathname,
    '--child-app', root, ...(required ? ['--require-setup', 'true'] : [])], { encoding: 'utf8' })
  return { root, unpacked, run }
}

test('requires real matching files and a working external Python entrypoint', t => {
  const f = fixture(t); const result = f.run()
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stdout, /external Python loads the wizard/)
})
test('rejects an archived-only setup script', t => {
  const f = fixture(t); unlinkSync(join(f.unpacked, 'skills/scnet-hpc/scripts/scnet.py'))
  const result = f.run(); assert.notEqual(result.status, 0); assert.match(result.stderr, /external file missing or changed/)
})
test('rejects changed physical modules even when the archive is intact', t => {
  const f = fixture(t); writeFileSync(join(f.unpacked, 'connector/callback.mjs'), 'changed')
  const result = f.run(); assert.notEqual(result.status, 0); assert.match(result.stderr, /external file missing or changed/)
})
test('rejects Python import failure with matching file hashes', t => {
  const f = fixture(t, 'import dsh_missing_module_for_audit\n')
  const result = f.run(); assert.notEqual(result.status, 0); assert.match(result.stderr, /external Python could not load/)
})
test('preserves historical package audits when setup acceptance is not requested', t => {
  const f = fixture(t); rmSync(f.unpacked, { recursive: true })
  const result = f.run(false); assert.equal(result.status, 0, result.stderr)
  assert.doesNotMatch(result.stdout, /external Python loads the wizard/)
})

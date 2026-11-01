import { test } from 'node:test'
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { createHash, generateKeyPairSync } from 'node:crypto'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(fileURLToPath(new URL('..', import.meta.url)))
const sign = join(root, 'ci/sign-release.mjs')
const verify = join(root, 'ci/verify-release-signature.mjs')

function fixture() {
  const directory = mkdtempSync(join(tmpdir(), 'release-signature-'))
  const { privateKey, publicKey } = generateKeyPairSync('ed25519')
  writeFileSync(join(directory, 'key.pem'), privateKey.export({ type: 'pkcs8', format: 'pem' }))
  writeFileSync(join(directory, 'key.pub.pem'), publicKey.export({ type: 'spki', format: 'pem' }))
  const artifact = join(directory, 'package.deb')
  writeFileSync(artifact, 'release bytes')
  writeFileSync(join(directory, 'SHA256SUMS'),
    `${createHash('sha256').update('release bytes').digest('hex')}  package.deb\n`)
  return directory
}

test('a signed manifest verifies and a tampered package is rejected', (t) => {
  const directory = fixture()
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  execFileSync(process.execPath, [sign, '--manifest', join(directory, 'SHA256SUMS'),
    '--key', join(directory, 'key.pem')], { stdio: 'pipe' })
  execFileSync(process.execPath, [verify, '--manifest', join(directory, 'SHA256SUMS'),
    '--public-key', join(directory, 'key.pub.pem')], { stdio: 'pipe' })

  writeFileSync(join(directory, 'package.deb'), 'tampered bytes')
  assert.throws(() => execFileSync(process.execPath, [verify, '--manifest', join(directory, 'SHA256SUMS'),
    '--public-key', join(directory, 'key.pub.pem')], { stdio: 'pipe' }))
})

test('a manifest signed by another key is rejected', (t) => {
  const directory = fixture()
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  execFileSync(process.execPath, [sign, '--manifest', join(directory, 'SHA256SUMS'),
    '--key', join(directory, 'key.pem')], { stdio: 'pipe' })
  const other = mkdtempSync(join(tmpdir(), 'release-signature-other-'))
  t.after(() => rmSync(other, { recursive: true, force: true }))
  const { publicKey } = generateKeyPairSync('ed25519')
  writeFileSync(join(other, 'other.pub.pem'), publicKey.export({ type: 'spki', format: 'pem' }))
  assert.throws(() => execFileSync(process.execPath, [verify, '--manifest', join(directory, 'SHA256SUMS'),
    '--public-key', join(other, 'other.pub.pem')], { stdio: 'pipe' }))
})

test('signing refuses a key that does not match the committed public key', (t) => {
  const directory = fixture()
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const { publicKey } = generateKeyPairSync('ed25519')
  writeFileSync(join(directory, 'other.pub.pem'), publicKey.export({ type: 'spki', format: 'pem' }))
  assert.throws(() => execFileSync(process.execPath, [sign, '--manifest', join(directory, 'SHA256SUMS'),
    '--key', join(directory, 'key.pem'), '--public-key-hint', join(directory, 'other.pub.pem')], { stdio: 'pipe' }))
})

#!/usr/bin/env node
/**
 * Verify a published checksum manifest and the package it lists against the pinned release key.
 *
 * This is the same check the installed application performs, runnable on release bytes:
 * it reads the committed public key, verifies the detached Ed25519 signature over the
 * manifest, then compares every listed file's SHA-256.
 *
 * Usage:
 *   node ci/verify-release-signature.mjs --manifest SHA256SUMS [--signature SHA256SUMS.sig]
 *       [--public-key ci/release-signing-key.pub.pem] [--directory .]
 */
import { createHash, createPublicKey, verify } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import process from 'node:process'

function argument(name, fallback) {
  const index = process.argv.indexOf(name)
  return index === -1 ? fallback : process.argv[index + 1]
}

const manifestPath = argument('--manifest', 'SHA256SUMS')
const signaturePath = argument('--signature', `${manifestPath}.sig`)
const publicKeyPath = argument('--public-key', join(import.meta.dirname, 'release-signing-key.pub.pem'))
const directory = resolve(argument('--directory', dirname(manifestPath)))

const manifest = readFileSync(manifestPath)
const detached = Buffer.from(readFileSync(signaturePath, 'utf8').trim(), 'base64')
if (!verify(null, manifest, createPublicKey(readFileSync(publicKeyPath, 'utf8')), detached)) {
  console.error('verify-release: manifest signature does not match the pinned release key')
  process.exit(1)
}
console.log('verify-release: manifest signature OK')

let files = 0
for (const line of manifest.toString('utf8').split(/\r?\n/u)) {
  if (line.trim() === '') continue
  const match = /^([a-f0-9]{64})\s+\*?(.+)$/u.exec(line)
  if (match === null) {
    console.error(`verify-release: unparsable manifest line: ${line}`)
    process.exit(1)
  }
  const [, expected, name] = match
  const actual = createHash('sha256').update(readFileSync(join(directory, name))).digest('hex')
  if (actual !== expected) {
    console.error(`verify-release: checksum mismatch for ${name}`)
    process.exit(1)
  }
  files += 1
}
if (files === 0) {
  console.error('verify-release: the manifest lists no files')
  process.exit(1)
}
console.log(`verify-release: ${files} file(s) match their signed checksums`)

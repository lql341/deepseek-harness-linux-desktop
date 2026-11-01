#!/usr/bin/env node
/**
 * Sign the release checksum manifest with the port's Ed25519 release key.
 *
 * The key never lives in the repository. CI reads it from the
 * `DSH_RELEASE_SIGNING_KEY` secret (PKCS#8 PEM); a local release reads the same
 * variable or `--key <path>`. The matching public key is committed as
 * `ci/release-signing-key.pub.pem` and is also compiled into the application, so
 * a client verifies the manifest against the same bytes this script signs.
 *
 * Usage:
 *   node ci/sign-release.mjs --manifest SHA256SUMS [--key key.pem] [--output SHA256SUMS.sig]
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { createPublicKey, sign } from 'node:crypto'
import process from 'node:process'

function argument(name) {
  const index = process.argv.indexOf(name)
  return index === -1 ? undefined : process.argv[index + 1]
}

const manifestPath = argument('--manifest')
if (manifestPath === undefined) {
  console.error('sign-release: --manifest <path> is required')
  process.exit(2)
}
const outputPath = argument('--output') ?? `${manifestPath}.sig`
const publicKeyHint = argument('--public-key-hint')
const keyPath = argument('--key')
const keyPem = keyPath === undefined ? process.env.DSH_RELEASE_SIGNING_KEY : readFileSync(keyPath, 'utf8')
if (keyPem === undefined || keyPem.trim() === '') {
  console.error('sign-release: set DSH_RELEASE_SIGNING_KEY or pass --key <path>')
  process.exit(2)
}

// The signature covers the manifest bytes exactly as published; nothing is normalised,
// so a client that hashes the downloaded file verifies the same input.
const manifest = readFileSync(manifestPath)
const signature = sign(null, manifest, keyPem)
const detached = signature.toString('base64')
writeFileSync(outputPath, `${detached}\n`, { mode: 0o644 })
console.log(`sign-release: wrote ${outputPath} (${detached.length} base64 characters)`)
if (publicKeyHint !== undefined) {
  // An operator mistake here would publish bytes no client accepts; compare the two copies.
  const expected = readFileSync(publicKeyHint, 'utf8').trim()
  const actual = createPublicKey(keyPem).export({ type: 'spki', format: 'pem' }).toString().trim()
  if (actual !== expected) {
    console.error(`sign-release: the signing key does not match ${publicKeyHint}`)
    process.exit(1)
  }
  console.log(`sign-release: signing key matches ${publicKeyHint}`)
}

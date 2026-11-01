import { test } from 'node:test'
import assert from 'node:assert/strict'
import { cpSync, mkdtempSync, readFileSync, rmSync, unlinkSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { checkDocs } from './check-docs.mjs'

const source = resolve(fileURLToPath(new URL('..', import.meta.url)))
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'bilingual-docs-'))
  cpSync(source, root, { recursive: true, filter: path => !relative(source, path).split(sep).some(part => ['.git', 'node_modules'].includes(part)) })
  t.after(() => rmSync(root, { recursive: true, force: true }))
  return root
}
function edit(root, path, before, after) {
  const file = join(root, path)
  const content = readFileSync(file, 'utf8')
  assert.ok(content.includes(before), `missing fixture target: ${before}`)
  writeFileSync(file, content.replace(before, after))
}

test('the complete repository has paired English defaults and Chinese pages', () => {
  assert.deepEqual(checkDocs(source), { pairs: 15, pages: 30 })
})
for (const [name, mutate, failure] of [
  ['missing translation', root => unlinkSync(join(root, 'docs/DOCUMENTATION.zh-CN.md')), /missing translation/],
  ['unpaired page', root => writeFileSync(join(root, 'unpaired.md'), '# Unpaired\n'), /unpaired Markdown/],
  ['wrong language switch', root => edit(root, 'README.md', '[中文](README.zh.md)', '[中文](missing.md)'), /English switch/],
  ['wrong-language navigation', root => edit(root, 'README.md', '(LINUX-DESKTOP.md)', '(LINUX-DESKTOP.zh-CN.md)'), /wrong-language navigation/],
  ['broken local link', root => edit(root, 'README.md', '(LINUX-DESKTOP.md)', '(missing.md)'), /broken local link/],
  ['broken anchor', root => edit(root, 'README.md', '(LINUX-DESKTOP.md)', '(LINUX-DESKTOP.md#missing-anchor)'), /broken anchor/],
  ['different command', root => edit(root, 'README.zh.md', 'pnpm run typecheck', 'pnpm run test'), /commands differ/],
  ['different release version', root => edit(root, 'README.zh.md', 'v0.2.1-rc.5-linux.1', 'v0.2.1-rc.5-linux.9'), /versions\/hashes\/run IDs differ/],
  ['broken table continuation', root => edit(root, 'docs/DESKTOP-FOLLOWUP.zh-CN.md', '\n| 0009 |', '\n\n| 0009 |'), /table structure differs/],
  ['missing translated table row', root => edit(root, 'docs/DESKTOP-FOLLOWUP.zh-CN.md', '| 0009 |', '0009 |'), /table structure differs/],
  ['invalid pinned base', root => writeFileSync(join(root, 'ci/upstream-base-tag'), 'not-a-tag\n'), /invalid pinned base/],
]) {
  test(`rejects ${name}`, t => {
    const root = fixture(t); assert.doesNotThrow(() => checkDocs(root)); mutate(root); assert.throws(() => checkDocs(root), failure)
  })
}

test('valid upstream migrations do not invalidate dated verification snapshots', t => {
  const root = fixture(t)
  writeFileSync(join(root, 'ci/upstream-base-tag'), 'dsh-v9.9.9-rc.1\n')
  assert.deepEqual(checkDocs(root), { pairs: 15, pages: 30 })
})

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { dirname, basename, resolve, relative, extname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const read = path => readFileSync(path, 'utf8')
const prose = text => text.replace(/^```[^\n]*\n[\s\S]*?^```\s*$/gm, '')
const headings = text => [...prose(text).matchAll(/^(#{1,6})\s+(.+)$/gm)]
const slug = text => text.toLowerCase().replace(/<[^>]+>/g, '').replace(/[^\p{L}\p{N}_\-\s]/gu, '').replace(/\s/g, '-')
const executableBlocks = text => [...text.matchAll(/^```([^\n]*)\n([\s\S]*?)^```\s*$/gm)]
  .filter(match => match[1].trim() !== 'text').map(match => match[1] + '\n' + match[2])
const facts = text => [...new Set(text.match(/\b(?:dsh-v|v)?\d+\.\d+\.\d+(?:[-.][\w.]+)*|\b[a-f0-9]{40,64}\b|\b\d{10,}\b/g) ?? [])].sort()

/** Check the repository-owned Markdown inventory; throws on every detected inconsistency. */
export function checkDocs(root) {
  const pairs = JSON.parse(read(resolve(root, 'ci/docs-pairs.json')))
  const owned = new Map()
  const errors = []
  const fail = message => errors.push(message)
  for (const pair of pairs) {
    for (const lang of ['en', 'zh']) {
      const path = pair[lang]
      if (typeof path !== 'string' || owned.has(path)) { fail(`invalid or duplicate pair: ${String(path)}`); continue }
      owned.set(path, { lang, pair })
      if (!existsSync(resolve(root, path))) fail(`missing translation: ${path}`)
    }
    if (/\.zh(?:-CN)?\.md$/.test(pair.en) || !/\.zh(?:-CN)?\.md$/.test(pair.zh)) fail(`default must be English: ${pair.en}`)
  }
  const walk = directory => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (['.git', 'node_modules'].includes(entry.name)) continue
      const path = resolve(directory, entry.name)
      if (entry.isDirectory()) walk(path)
      else if (entry.isFile() && entry.name.endsWith('.md')) {
        const name = relative(root, path).replaceAll('\\', '/')
        if (!owned.has(name)) fail(`unpaired Markdown: ${name}`)
      }
    }
  }
  walk(root)
  for (const pair of pairs) {
    const enPath = resolve(root, pair.en), zhPath = resolve(root, pair.zh)
    if (!existsSync(enPath) || !existsSync(zhPath)) continue
    const en = read(enPath), zh = read(zhPath)
    if (en.split('\n')[0] !== `English | [中文](${basename(pair.zh)})`) fail(`English switch: ${pair.en}`)
    if (zh.split('\n')[0] !== `[English](${basename(pair.en)}) | 中文`) fail(`Chinese switch: ${pair.zh}`)
    if (/\p{Script=Han}/u.test(prose(en).split('\n').slice(1).join('\n'))) fail(`English prose contains Chinese: ${pair.en}`)
    if (JSON.stringify(headings(en).map(x => x[1])) !== JSON.stringify(headings(zh).map(x => x[1]))) fail(`heading structure differs: ${pair.en}`)
    if (JSON.stringify(executableBlocks(en)) !== JSON.stringify(executableBlocks(zh))) fail(`commands differ: ${pair.en}`)
    if (JSON.stringify(facts(en)) !== JSON.stringify(facts(zh))) fail(`versions/hashes/run IDs differ: ${pair.en}`)
    for (const [path, text, lang] of [[pair.en, en, 'en'], [pair.zh, zh, 'zh']]) {
      for (const match of prose(text).matchAll(/!?\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)/g)) {
        const target = match[1]
        if (/^[a-z][a-z\d+.-]*:/i.test(target) || target.startsWith('//')) continue
        let local, anchor
        try { [local, anchor] = target.split('#').map(decodeURIComponent) }
        catch { fail(`invalid link encoding: ${path}: ${target}`); continue }
        const absolute = local ? resolve(dirname(resolve(root, path)), local.split('?')[0]) : resolve(root, path)
        const targetPath = relative(root, absolute).replaceAll('\\', '/')
        if (targetPath.startsWith('../') || !existsSync(absolute)) { fail(`broken local link: ${path}: ${target}`); continue }
        const targetOwner = owned.get(targetPath)
        if (targetOwner && targetOwner.lang !== lang && match.index > text.indexOf('\n')) fail(`wrong-language navigation: ${path}: ${target}`)
        if (anchor && extname(absolute) === '.md' && statSync(absolute).isFile()) {
          const content = read(absolute)
          const counts = new Map()
          const anchors = new Set(headings(content).map(h => {
            const id = slug(h[2]); const count = counts.get(id) ?? 0; counts.set(id, count + 1)
            return count === 0 ? id : `${id}-${count}`
          }))
          for (const h of content.matchAll(/<(?:a|h[1-6])\b[^>]*\bid=["']([^"']+)["']/g)) anchors.add(h[1])
          if (!anchors.has(anchor)) fail(`broken anchor: ${path}: ${target}`)
        }
      }
    }
  }
  const base = read(resolve(root, 'ci/upstream-base-tag')).trim()
  if (!/^dsh-v\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$/.test(base)) fail(`invalid pinned base: ${base}`)
  if (errors.length) throw new Error(errors.join('\n'))
  return { pairs: pairs.length, pages: owned.size }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
  try { const result = checkDocs(root); console.log(`PASS: ${result.pairs} bilingual pairs, ${result.pages} Markdown pages`) }
  catch (error) { console.error(error.message); process.exitCode = 1 }
}

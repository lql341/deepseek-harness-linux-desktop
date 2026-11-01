English | [中文](DOCUMENTATION.zh-CN.md)

# Documentation maintenance

English is the default for repository entry pages and guides. Every Markdown document belongs to an English/Chinese pair in [ci/docs-pairs.json](../ci/docs-pairs.json). Keep established Chinese filenames, including README.zh.md; new standalone Chinese pages use .zh-CN.md. Put a reciprocal language switch on the first line and keep each language's navigation in that language.

Update both pages in the same PR. Check commands, versions, paths, source/release status, limitations and evidence together. Handoff snapshots are dated records, not live status; replace obsolete current-state instructions rather than presenting historical patch counts as current. Git history retains older snapshots. Runtime UI translations are maintained separately in the upstream locale patch.

## Automated checks

```sh
node ci/check-docs.mjs
node --test ci/check-docs.test.mjs
```

The documentation CI checks every Markdown page is paired, default names point to English, switches are reciprocal, English prose is English, local files/anchors exist, navigation preserves language, headings have matching structure, executable fenced blocks agree and concrete versions/hashes/run IDs match across translations. It also validates the pinned tag format in ci/upstream-base-tag. Build guides link that source; recorded verification versions are dated evidence, so a valid upstream migration does not require rewriting historical results.

Negative fixtures verify that missing translations, broken links/anchors, wrong-language navigation, changed commands and invalid base tags are rejected. These structural checks do not certify semantic translation quality or external URL availability. Review both languages against code, exact CI logs and published bytes before merging. A CI candidate must not be described as a public release.

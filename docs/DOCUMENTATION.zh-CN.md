[English](DOCUMENTATION.md) | 中文

# 文档维护

仓库入口和指南默认英文。每篇 Markdown 都必须登记为 [ci/docs-pairs.json](../ci/docs-pairs.json) 中的英文/中文配对。保留现有中文文件名（包括 README.zh.md），新增独立中文页用 .zh-CN.md。第一行放双向语言切换，同语言导航保持同语言。

同一个 PR 同步修改两页，同时核对命令、版本、路径、源码/发布状态、限制和证据。交接快照是带日期记录，不是实时状态；替换过时的当前操作说明，不把历史补丁数量当作当前值。Git 历史保留旧快照。运行时 UI 翻译在上游 locale 补丁中单独维护。

## 自动检查

```sh
node ci/check-docs.mjs
node --test ci/check-docs.test.mjs
```

文档 CI 检查所有 Markdown 都配对、默认文件名为英文、切换互相对应、英文正文为英文、本地文件/锚点存在、导航语言正确、标题层级结构对应、可执行 fenced block 一致，以及具体版本/哈希/run ID 在翻译中一致；还验证 ci/upstream-base-tag 的固定 tag 格式。构建指南引用该源头，已记录验证版本是带日期证据，因此正常上游迁移不要求重写历史结果。

反例 fixture 验证缺翻译、坏链接/锚点、导航语言错误、命令变化和基线 tag 无效会被拒绝。结构检查不能保证语义翻译质量或外部 URL 可达；合并前仍须对照源码、精确 CI 日志和发布字节审查两种语言。CI 候选包不能描述成公开 release。

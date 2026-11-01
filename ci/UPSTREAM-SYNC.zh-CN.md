[English](UPSTREAM-SYNC.md) | 中文

# 上游同步

`ci/upstream-base-tag` 是 apply.sh、本地迁移、验证和发布的默认版本。对应本地脚本可通过 `BASE_TAG` 和 `DSH_BASE_TAG` 覆盖。

每日 workflow 验证较新的后继 tag。迁移 PR 修改普通基线文件，不需要 workflow 文件写权限。验证 job 只有 contents/actions 只读权限，创建 PR 的 job 有 contents/pull-requests 写权限。仓库必须允许 GitHub Actions 创建 PR；本仓库已启用该设置，默认 token 仍只读，合并是单独动作。

成功构建和明确的补丁冲突作为 90 天 artifact 缓存，同时按移植仓库提交和上游提交 SHA 索引；后续运行复用最新精确匹配。新的明确补丁冲突会让运行成功，并创建或更新一条 `Upstream sync blocked: the patch series conflicts with …` issue，附上运行链接和 artifact 说明；从缓存复用的冲突不会重复开 issue，因为只有人工修改补丁才能解除。摘要会链接原始 run 并明确显示迁移阻塞；缓存冲突不会创建 PR。输入变化或过期后重新验证。依赖、构建和基础设施失败仍会让运行失败且不缓存，后续会重试；只有这类失败会发送通知。

使用 **Run workflow → force** 重新验证未变输入并替代旧冲突结果。复用成功结果仍会重试创建 PR，所以权限修复后不必重建。遗留自动化分支只有树与预期迁移完全一致才复用；不同树需要审查。匹配的已有 PR 会复用，不会重复创建。

发往 main 的相关 PR 会运行 Linux 验证，包括版本变更。机器人 PR 可能需要 GitHub workflow 批准；合并前确认实际检查通过，不能把“已建 PR”当作“验证已执行”。发布保持手动，上游同步不会合并或发布。

保留上游历史，是因为基线升级后的三方应用需要旧 blob 对象。脚本使用 `git apply --3way` 暂存补丁；`git write-tree` 记录补丁树，`HEAD` 仍标识检出的基线。

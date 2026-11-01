# Desktop 平台跟进检查（2026-11-01）

## 范围与结论

本次 Linux 版本采用上游 `dsh-v0.2.1-rc.5`；检查 macOS/Windows 原生桌面壳、安装更新和系统集成，不仅检查共享 Harness 核心。

- [rc.2 → rc.5 的完整比较](https://github.com/deepseek-ai/deepseek-harness/compare/dsh-v0.2.1-rc.2...dsh-v0.2.1-rc.5)共 19 个提交；`apps/desktop/` 只有 `package.json` 的版本号变化。该稳定候选线没有遗漏新增的原生桌面壳代码。
- 共享客户端的插件入口、草稿保留、思考展示等随 rc.5 一起升级，不等于新增了原生桌面功能。
- 开发分支另行检查于 [ce7073d51254c26cd63b22a60835b8f948deb447](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447)。下面的开发分支能力不属于本次 rc.5，不能据此宣称 Linux 已支持。
- 本次为源码和发布流程核对；Linux 验证以链接的 CI/发布记录为准，没有在 macOS 或 Windows 上进行实机测试。

## 后续优先跟进

| 方向 | 上游证据 | Linux 跟进及验收 |
| --- | --- | --- |
| CUA 按需交付与授权（高） | [Desktop 按需安装与授权提交](https://github.com/deepseek-ai/deepseek-harness/commit/c6f3dff0314294aa378392573f94f8b061296281)、[macOS 独立权限 helper](https://github.com/deepseek-ai/deepseek-harness/commit/e27306b2a0ad6810b65d0d3c2861e1fe594a5814) | 先核对上游支持的平台，再设计 Linux 安装、权限拒绝/重试/撤销路径；分别验证 X11/Wayland，不能照搬 macOS 权限模型。未验证前不标为已支持。 |
| 原生菜单中的 DevTools（中） | [菜单开关提交](https://github.com/deepseek-ai/deepseek-harness/commit/4d5945cb724e4eae464e7d494041121f115f51be)、`apps/desktop/src/main.ts` | 核对 Linux 菜单可见性、文案、F12 与 Ctrl+Shift+I、焦点路由；更新蒙层与不可信嵌入页不得获得额外调试权限。 |
| 文件交互与系统桥接（中） | 开发分支的 `file-actions.ts`、`file-drag.ts`、`platform-view.ts`、`preload-app.ts` 与 rc.5 blob 不同 | 升级开发线时审查目录选择、文件拖入/拖出、嵌入视图的存储隔离与外链；用真实桌面验证，不能仅凭 typecheck。此处为待评估差异，不逐项声称新功能。 |
| 更新弹窗与窗口行为（中） | 开发分支新增 `update-window.ts`，更新 `update-dialog.ts`、`update-overlay.ts`、`update-presentation.ts` | 与现有 Linux PolicyKit 安装、自动下载、后台任务及重启确认补丁一起迁移，防止平台分支覆盖现有 Linux 行为。 |
| 诊断与故障恢复（中） | 开发分支的 `operation-history.ts`、`operation-report*.ts`、`crash-report.ts`、`fatal-recovery.ts` 与 rc.5 blob 不同；[上游诊断文档](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/docs/diagnostics) | 审查本地操作记录、报告导出及恢复流程；验证日志脱敏、失败时可恢复及 Linux 路径权限。 |

## 平台差异与发布边界

macOS Dock/红绿灯、Windows 托盘与安装器、Linux 托盘/PolicyKit/桌面协议不是相同的实现。后续验收应按能力检查：关窗保留任务、重新唤回、退出确认、快捷键、通知、深链、命令入口和更新重启。

本次保留已经验证的 rc.5 线，不将大量开发分支改动直接混入发布。后续迁移应先在独立分支解决补丁及平台差异，再增加相应测试和 X11/Wayland 实机证据。

## 复核入口

- [固定基线文件](../ci/upstream-base-tag)
- [Linux 验证流程](../.github/workflows/linux-desktop-verify.yml)
- [发布流程](../.github/workflows/publish-linux-desktop.yml)
- [上游原生桌面说明（本次核对提交）](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/README.zh.md)

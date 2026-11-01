# Desktop 平台跟进检查（2026-11-01）

## 范围与结论

本次 Linux 版本采用上游 `dsh-v0.2.1-rc.5`；检查 macOS/Windows 原生桌面壳、安装更新和系统集成，不仅检查共享 Harness 核心。

- [rc.2 → rc.5 的完整比较](https://github.com/deepseek-ai/deepseek-harness/compare/dsh-v0.2.1-rc.2...dsh-v0.2.1-rc.5)共 19 个提交；`apps/desktop/` 只有 `package.json` 的版本号变化。该稳定候选线没有遗漏新增的原生桌面壳代码。
- 共享客户端的插件入口、草稿保留、思考展示等随 rc.5 一起升级，不等于新增了原生桌面功能。
- 开发分支另行检查于 [ce7073d51254c26cd63b22a60835b8f948deb447](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447)。补丁 `0007` 选择性回移下面三项桌面能力；已发布的 `v0.2.1-rc.5-linux.1` 尚不包含该补丁。
- 本次为源码和发布流程核对；Linux 验证以链接的 CI/发布记录为准，没有在 macOS 或 Windows 上进行实机测试。

## 已回移至补丁的能力

- **开发者工具菜单**：提供中英文可见入口，保留原生快捷键及 F12；保留 Linux 的显示窗口、退出和 SCNet 诊断入口。菜单测试覆盖 Linux、macOS、Windows 与中英文组合。
- **崩溃诊断报告获取**：恢复窗口显示报告保存中、失败或路径；可打开现有报告所在目录，慢写入完成后可再次获取。获取报告本身不停止任务、不重启应用；打开失败保留路径并给出提示。此项不包含开发线完整操作历史。
- **更新弹窗与故障恢复**：更新文档附着在主窗口内，不另建会抢焦点的原生窗口；适配 Linux 自绘标题栏、原生边框和全屏切换。覆盖并存弹窗的输入阻断与销毁清理、取消安装、旧确认失效、导航限制，以及强制更新视图加载或渲染失败时的原生恢复提示。保留 Linux PolicyKit 安装流程。

对应四组行为单元测试在隔离的本地环境通过，共 74 项。仓库 CI 另运行完整源码的类型检查、上述测试、主进程启动、Linux 更新及 SCNet 窗口回归测试，再构建、安装并检查候选 deb。单元测试使用 Electron 替身；不能据此声称真实桌面的焦点或 X11/Wayland 操作已全部验证。

## 仍需跟进的能力

| 方向 | 上游证据 | Linux 跟进及验收 |
| --- | --- | --- |
| CUA 按需交付与授权（高） | [Desktop 按需安装与授权提交](https://github.com/deepseek-ai/deepseek-harness/commit/c6f3dff0314294aa378392573f94f8b061296281)、[macOS 独立权限 helper](https://github.com/deepseek-ai/deepseek-harness/commit/e27306b2a0ad6810b65d0d3c2861e1fe594a5814) | 先核对上游支持的平台，再设计 Linux 安装、权限拒绝/重试/撤销路径；分别验证 X11/Wayland，不能照搬 macOS 权限模型。未验证前不标为已支持。 |
| 文件交互与系统桥接（中） | 开发分支的 `file-actions.ts`、`file-drag.ts`、`platform-view.ts`、`preload-app.ts` 与 rc.5 blob 不同 | 升级开发线时审查目录选择、文件拖入/拖出、嵌入视图的存储隔离与外链；用真实桌面验证，不能仅凭 typecheck。此处为待评估差异，不逐项声称新功能。 |
| 诊断与故障恢复（中） | 开发分支的 `operation-history.ts`、`operation-report*.ts`、`crash-report.ts`、`fatal-recovery.ts` 与 rc.5 blob 不同；[上游诊断文档](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/docs/diagnostics) | 审查本地操作记录、报告导出及恢复流程；验证日志脱敏、失败时可恢复及 Linux 路径权限。 |

## 平台差异与发布边界

macOS Dock/红绿灯、Windows 托盘与安装器、Linux 托盘/PolicyKit/桌面协议不是相同的实现。后续验收应按能力检查：关窗保留任务、重新唤回、退出确认、快捷键、通知、深链、命令入口和更新重启。

本次保留 rc.5 共享核心，单独回移可独立集成的桌面能力。CUA 的 macOS provider 依赖 macOS 原生 API；Linux 需要单独实现和验证权限及图形协议。开发线文件交互依赖 rc.5 尚无的共享文件动作协议与拖放包，完整操作历史依赖新的插件诊断协议；这些不能靠复制桌面入口安全补齐。后续迁移继续在独立分支完成，并增加 X11/Wayland 实机证据。

## 复核入口

- [固定基线文件](../ci/upstream-base-tag)
- [Linux 验证流程](../.github/workflows/linux-desktop-verify.yml)
- [发布流程](../.github/workflows/publish-linux-desktop.yml)
- [上游原生桌面说明（本次核对提交）](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/README.zh.md)

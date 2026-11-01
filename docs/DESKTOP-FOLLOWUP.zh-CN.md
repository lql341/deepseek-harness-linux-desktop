[English](DESKTOP-FOLLOWUP.md) | 中文

# 桌面平台功能跟进

2026-11-01 核对上游 `dsh-v0.2.1-rc.5` 与开发提交 `ce7073d51254c26cd63b22a60835b8f948deb447`。本文记录实现和证据，不表示平台能力已完全对齐。

## 稳定基线与公开包

[rc.2 到 rc.5](https://github.com/deepseek-ai/deepseek-harness/compare/dsh-v0.2.1-rc.2...dsh-v0.2.1-rc.5) 共 19 个提交，desktop 目录只修改包版本。共享客户端改进随 rc.5 升级，不代表具备开发线新增的原生壳能力。

公开的 `v0.2.1-rc.5-linux.1` 早于补丁 0007、0008 和 0009，源码、CI 候选包和 release 必须分别核查。

## 当前源码补丁已实现

| 补丁 | 能力 | 验证 |
| --- | --- | --- |
| 0007 | 中英文可见 DevTools 菜单、原生快捷键/F12，保留 Linux 显示窗口/退出和 SCNet 入口 | 菜单测试覆盖 Linux/macOS/Windows 和中英文 |
| 0007 | 获取崩溃报告，区分保存中/失败/已保存，支持慢写入、可见打开失败和保留路径 | 获取本身不停止任务或重启，有定向恢复测试 |
| 0007 | 主窗口内隔离更新视图、不独立激活原生窗口，适配标题栏/原生边框/全屏，清理输入和生命周期，处理取消与强更视图恢复 | 生命周期/导航定向测试，加 Linux 主进程/键盘/更新/SCNet 集成回归 |
| 0008 | 修复配置 SCNet 的外部 Python ASAR 路径，解包完整 Bundle，保留终端输出并拒绝启动失败 | 源码测试和包审计要求物理文件哈希一致，并由外部 Python 执行帮助命令 |
| 0009 | 关联管理操作事件、校验 Host IPC、跨 Host 重启的有界本地记录，以及隔离的诊断报告 Worker | 候选版本：源码测试加随包管理器真实变更和物理 Worker 验收；完整 CI 待完成 |

补丁 0007 在 [Run 41273560891](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41273560891) 通过八组共 254 项测试、全仓类型检查、构建、deb 审计和安装后的 Xvfb 会话；合并后 main 在 [Run 41274912984](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41274912984) 通过。补丁 0008 随后在 [Run 41278271808](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41278271808) 通过十组共 268 项测试、全仓类型检查、deb 构建、SCNet 物理文件与外部 Python 验收，以及安装后会话。26 页双语文档检查和十一项守卫测试通过 [Run 41278271805](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41278271805)。PR #6 已合并为 `c23d3cb6c849307d6eaaa2640016ec9b26436c8c`。补丁 0009 是新的候选版本，仍需完整 CI 和随包管理器/Worker 验收。

历史仅保存在本地，最多两个 256 KiB 分段；报告收集最多读取 64 KiB/100 条记录，并在独立基础报告保存后追加最多 64 KiB。原始安装参数、凭据和包管理器输出不进入记录。遗漏计数和完成标记说明不完整情况；没有记录不能证明没有操作。

## 仍需跟进

| 能力 | 依赖和出口条件 |
| --- | --- |
| CUA 安装与授权 | [macOS provider](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/cua-macos) 使用 macOS API；Linux 需要原生控制/权限实现，以及 X11/Wayland 的允许、拒绝、重试和撤销测试 |
| 新文件动作与拖放 | 开发线 file-actions/file-drag 依赖 rc.5 没有的共享文件动作、拖放和 Host 资源 API，需一起回移 provider、consumer 和生命周期，覆盖可信窗口 IPC 和临时文件清理 |
| 真实桌面验收 | 在实际 X11/Wayland 会话验证焦点、标题栏拖拽/缩放、蒙层、通知、CLI、深链、配置和更新确认 |

后续回移必须保留 Linux PolicyKit 安装和 SCNet 集成回归。macOS Dock/红绿灯、Windows 安装器和 Linux 合成器/keyring API 各自有不同实现；不能用类型检查或复制菜单入口替代平台证据。

## 参考

- [固定基线](../ci/upstream-base-tag)
- [Linux 验证流程](../.github/workflows/linux-desktop-verify.yml)
- [发布流程](../.github/workflows/publish-linux-desktop.yml)
- [Linux 指南](../LINUX-DESKTOP.zh-CN.md)
- [桌面平台能力对齐](DESKTOP-PARITY.zh-CN.md)
- [dsh-superagent 附加组件决策](roadmap/ADR-0002-dsh-superagent-bundle.zh-CN.md)

[English](README.md) | 中文

# DeepSeek Harness Linux Desktop

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的非官方 Linux x64 桌面移植。本仓库维护按序应用的补丁，以及 Linux 构建、验证和发布工具。项目与 DeepSeek 无隶属关系，未获其背书。

当前上游基线是 **`dsh-v0.2.1-rc.5`**，由 [ci/upstream-base-tag](ci/upstream-base-tag) 提供。Linux 包固定携带 **`dsh-scnet@0.6.13`**。请在 [Actions](https://github.com/lql341/deepseek-harness-linux-desktop/actions) 查看具体提交的检查结果。

## 安装已发布的包

已验证的公开预发布版是 [v0.2.1-rc.5-linux.1](https://github.com/lql341/deepseek-harness-linux-desktop/releases/tag/v0.2.1-rc.5-linux.1)。可下载 deb 和 `SHA256SUMS`，或使用下方安装器。它校验 checksum 和 amd64 架构后，调用 apt 重新安装；安装主机需要 curl、Node、sha256sum、dpkg 和 sudo/apt。

```sh
git clone https://github.com/lql341/deepseek-harness-linux-desktop.git
cd deepseek-harness-linux-desktop
bash ci/install-latest-linux.sh --tag v0.2.1-rc.5-linux.1
```

不传 `--tag` 时，脚本使用 GitHub 的最新非预发布版本接口，因此可能选到较旧的稳定版。main 源码、CI 产物和公开 release 是不同交付物。上述 release **不包含**后来回移的桌面功能，也不包含下文的 SCNet 配置修复。

## 桌面能力

| 方向 | Linux 行为 |
| --- | --- |
| 窗口与后台任务 | 自绘标题栏、可选原生边框、托盘/显示窗口，关闭最后一个窗口后任务继续运行 |
| 系统集成 | `dsh` 启动器、单实例路由和已注册的 `dsh://` 深链 |
| 运行时 | Linux 目标运行时和内置 WASM Office 转换 |
| 更新 | 设置页检查/更新入口、已校验 Linux 包下载和 PolicyKit 安装；客户端与 Harness 整包交付 |
| SCNet | 固定离线 Bundle/Skill、Desktop profile 默认激活、保留显式禁用/自定义 profile、本地诊断 |
| 开发者工具 | 中英文可见菜单，保留包含 F12 的原生快捷键 |
| 故障恢复 | 获取已保存的崩溃报告，处理慢写入和打开位置失败 |
| 更新弹窗 | 主窗口内的隔离视图、Linux 标题栏/全屏适配、取消和强制更新视图恢复 |
| SCNet 配置修复 | 外部 Python 使用解包后的文件，终端保留完成/错误信息，启动失败会拒绝该动作 |

最后四行描述当前源码补丁。证据与剩余差异见[桌面功能跟进](docs/DESKTOP-FOLLOWUP.zh-CN.md)。真实 SCNet OAuth2 登录仍等待正式服务合同和沙盒凭证；本地诊断和 Bundle 已安装不能证明已获得账户授权。

## 从源码构建

构建主机必须是 **Linux x86_64**，具备 Node `^22.19.0 || >=24.0.0`、pnpm `11.7.0`、Git、构建所需网络和至少 15 GB 空闲磁盘。上游工作区可能通过包管理器管理机制选择其自身固定的 pnpm。本补丁线不支持在 macOS 上交叉构建该 Linux 目标，也不发布 `linux-arm64`。

```sh
export PATCH_REPO="$HOME/src/deepseek-harness-linux-desktop"
export SRC="$HOME/src/deepseek-harness"
git clone https://github.com/lql341/deepseek-harness-linux-desktop.git "$PATCH_REPO"
sh "$PATCH_REPO/apply.sh" "$SRC"
cd "$SRC"
pnpm install --frozen-lockfile
pnpm run typecheck
pnpm run build:lib:host
pnpm --dir apps/desktop run build
pnpm --dir apps/desktop run check:package
pnpm --dir apps/desktop run package:linux:x64
```

请使用全新的 `$SRC`。`apply.sh` 检出固定上游 tag，创建 Linux 分支，以 **`git apply --3way`** 按文件名顺序应用所有 `patches/*.patch`，并生成 `.env.linux`。改动处于暂存区，并非每个补丁生成一个提交。用 `git -C "$SRC" write-tree` 记录补丁后的源码树；`HEAD` 仍指向上游基线。详细构建步骤、路径和排障见 [Linux 指南](LINUX-DESKTOP.zh-CN.md)。

## 验证与发布

PR 和相关 main push 会应用补丁、检查全仓类型、运行定向桌面回归、构建 deb、审计 SCNet 内容，再在 Ubuntu 24.04 的 Xvfb 中安装并启动同一个候选包。普通第二次启动的窗口断言在无头会话中跳过，需要真实桌面验证。已发布字节、升级、AppArmor、Wayland 和 Debian 13 是单独的手动 job；跳过不等于平台检查通过。

[PR #5](https://github.com/lql341/deepseek-harness-linux-desktop/pull/5) 在 [Run 41273560891](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41273560891) 通过 254 项桌面回归、全仓类型检查、打包和安装会话检查；合并后的 main 也在 [Run 41274912984](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41274912984) 通过。这些运行早于 SCNet 配置修复，当前改动仍需自己的 CI 证据。

发布由 [publish-linux-desktop.yml](.github/workflows/publish-linux-desktop.yml) 手动触发：固定构建提交、记录暂存区补丁树、审计并安装构建字节，然后发布 deb 和 checksum。上游同步只创建可审查 PR，不会合并或发布，见[同步操作](ci/UPSTREAM-SYNC.zh-CN.md)。

## 文档与目录

文档默认英文，每页顶部都有中文版本切换；修改时必须同步两种语言。[文档维护说明](docs/DOCUMENTATION.zh-CN.md)介绍自动检查。

- [Linux 构建与验收指南](LINUX-DESKTOP.zh-CN.md)
- [桌面功能跟进](docs/DESKTOP-FOLLOWUP.zh-CN.md)
- [SCNet 路线图与交接](docs/roadmap/README.zh-CN.md)
- [Android/HarmonyOS 离线骨架](mobile-skeleton/README.zh-CN.md)
- `patches/`：当前上游差异；`patches-legacy-dsh-v0.2.0-rc.2/`：历史补丁线
- `apply.sh`、`verify.sh`、`ci/`：源码准备、诊断、审计和安装工具

本仓库当前只维护 Linux x64 deb 交付。macOS Dock/vibrancy、Windows 安装器和 Linux 权限/合成器需要不同实现。原生 CUA、新文件交互和完整插件操作历史仍待实现，依赖见功能跟进。

## 许可

[MIT](LICENSE)，保留上游 Copyright (c) 2026 DeepSeek。本项目为非官方补丁集；上游持续演进，升级 tag 时可能需要解决冲突。

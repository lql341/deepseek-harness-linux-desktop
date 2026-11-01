[English](DESKTOP-PARITY.md) | 中文

# 桌面平台能力对齐

本文对照官方 macOS 桌面版本与本仓库 Linux 移植版的桌面能力。它是一份带证据的现状清单，不表示两个平台的行为已经完全一致。

## 范围与证据

官方基线是上游 `dsh-v0.2.1-rc.5`，也就是发布 macOS 和 Windows 桌面外壳的版本。Linux 侧以 `patches/` 中的活动补丁系列和已发布的 `v0.2.1-rc.5-linux.1` 包为准。两个更晚的状态要分开看：补丁 0007、0008 和 0009 是比该发布包更新的源码，上游 `dsh-v0.2.2-alpha.2` 则是已经包含移植版仍在回移内容的开发线。

每一行的证据来自固定上游树和 `apply.sh` 生成的补丁树。最有用的文件是 `apps/desktop/src/main.ts`、`apps/desktop/src/windows-layout.ts`、`apps/desktop/src/platform-view.ts`、`apps/desktop/src/update-attention.ts`、`apps/desktop/src/command-management.ts`、`apps/desktop/scripts/electron-builder-config.mjs`，以及验证 workflow 运行的定向桌面测试。只有测试或发布门禁实际执行过的能力才算已具备；类型检查和照抄一个菜单项不能作为平台证据。

## 能力矩阵

| 领域 | 官方 macOS 桌面 | Linux 移植版 | 仍需开发 |
| --- | --- | --- | --- |
| 窗口外观 | `hiddenInset` 标题栏、内嵌红绿灯、侧栏毛玻璃和透明背景 | 40 DIP 自绘标题栏与窗口控件覆盖层、本地化标题栏菜单，或使用 `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` 恢复原生边框 | 毛玻璃和半透明依赖合成器，尚未实现；标题栏配色是静态的 |
| 全屏 | 原生全屏、覆盖层标题栏留白，隐藏窗口前先退出全屏 | 全屏状态会转给渲染层处理覆盖层留白；全屏时隐藏窗口没有单独处理 | 在 X11 和 Wayland 处理全屏隐藏并测试恢复路径 |
| 托盘与窗口恢复 | 没有菜单栏图标；Dock 图标和第二次启动恢复窗口 | 托盘 Open/Quit 加“显示窗口”菜单项；Dock 的等价物是启动器 | 托盘是否可用取决于桌面环境；没有扩展的 GNOME 只能靠重新启动 |
| 关闭与退出生命周期 | 关闭最后一个窗口后应用和任务继续运行 | 关闭最后一个窗口后 Host 和任务继续运行，与 macOS 一致而非 Windows | 在真实桌面确认隐藏窗口和 Host 能跨会话切换存活 |
| 更新提醒 | Dock 图标弹跳加系统通知 | 只有系统通知；既没有 Dock 弹跳也没有任务栏闪烁 | 增加 Linux 提醒机制，例如角标或 freedesktop 紧急提示 |
| 应用菜单 | File 菜单显示单键绑定、Edit、Window 和隐藏命令 | Application 与 Edit 自绘菜单加原生 Edit 菜单；没有 File 和 Window 菜单 | 可选：补 Window 菜单和单键绑定提示；DOM 分发已经可用 |
| 终端命令 | 通过管理员授权安装到 `/usr/local/bin/dsh` | 通过随包启动器安装到 `~/.local/bin/dsh`；命令管理 worker 已支持 Linux | “管理 dsh 命令”菜单项在 Linux 被隐藏，可用的安装路径没有界面 |
| 目录选择器 | 附着在主窗口上的 Electron 文件夹对话框 | 上游在缺少 zenity 和 kdialog 时已经回退到浏览模式，移植版保留该行为 | 在真实桌面验证回退和附着对话框 |
| 深链 | 由应用包注册 `dsh://`、`open-url` 和 Launch Services | 桌面项声明 `x-scheme-handler/dsh`、`xdg-mime`，并由单实例命令行路由 | `xdg-mime query default x-scheme-handler/dsh` 必须指向已安装的桌面项；失效即打包缺陷 |
| 单实例 | 访问 profile 前先取得进程生命周期锁 | 同一把锁；无头会话测试覆盖普通重启和 `dsh://open` | 普通第二次启动的窗口断言需要真实桌面 |
| 麦克风 | 系统授权、用途说明和音频输入 entitlement | 只接受主应用 frame 的请求；非 macOS 请求直接放行，没有系统弹窗 | 验证 PipeWire 和 PulseAudio 采集，并决定是否需要 portal 授权流程 |
| 账户登录与内嵌 Platform | 可接受的桌面平台值是 macOS 和 Windows；上游的登录按钮仍禁用 | 移植版因 Linux 不是可接受值而传入 macOS 回退值 | 需要上游接受 Linux，才能提供真实的客户端标识、内嵌 Platform 视图或登录 |
| 更新 | 官方更新服务的签名产物，带渠道和强制更新策略 | 从 GitHub release 发现更新、校验 checksum，并用 PolicyKit 安装重新构建的 deb | 签名软件包、让菜单动作走真实更新器，并决定强制更新如何适用 |
| 强制更新策略 | 策略服务接受 Windows 和 macOS 标识 | 因为 Linux 没有可接受标识，策略客户端被刻意不初始化 | 定义 Linux 标识和服务合同，或把豁免作为产品决策写明 |
| 软件包签名 | Developer ID 签名与公证 | 未签名的 deb 加 SHA256SUMS 文件 | 在推荐自动安装前增加仓库签名密钥或其他可验证信任链 |
| 打包目标 | macOS arm64 与 x64 镜像；Windows 安装器 | 只有 Linux x64 deb | Linux arm64、rpm、AppImage 和 Flatpak 需要各自的运行时与验收工作 |
| 沙箱与权限 | 强化运行时、entitlement 和 macOS 沙箱模型 | AppArmor 配置、SUID `chrome-sandbox` 回退，以及 bwrap 或 Landlock 沙箱用例 | 持续覆盖沙箱回退，并手动测试 Wayland 会话 |
| 开发者工具 | Command+Option+I 和隐藏菜单项 | F12、Ctrl+Shift+I、可见的中英文菜单项和原生快捷键 | 由定向键盘和菜单测试覆盖 |
| 崩溃恢复 | 报告写入 macOS 日志目录并显示原生对话框 | 报告写入 userData 日志目录，并可从设置菜单取回已保存报告 | 在真实桌面检查定位动作和十条报告保留策略 |
| 计算机操作 | 专用 macOS provider 使用辅助功能和屏幕录制权限 | 没有 Linux provider | 需要 X11 与 Wayland 的控制、无障碍树、截图和授权测试 |
| 原生文件拖拽与新文件动作 | 在开发线中，不在官方基线 | 固定基线中没有 | 需要一起回移文件拖拽 provider、Host 资源 API 和清理生命周期 |
| 插件操作历史 | 在开发线中，不在官方基线 | 补丁 0009 是回移候选 | 合并并发布后，在已安装包中验证记录和报告 Worker |

## 需要开发的能力缺口

| 优先级 | 缺口 | 依赖 | 出口条件 |
| --- | --- | --- | --- |
| P0 | 已发布包早于补丁 0007、0008 和 0009 | 合并操作历史 PR 并执行发布 workflow | 当前系列构建的已安装包通过验证并发布 |
| P0 | Linux 的“检查更新”菜单动作走的是不工作的上游渠道 | 主进程小改动，改为调用 Harness 更新协调器 | 菜单动作显示真实 Linux 发布状态，并有定向测试 |
| P0 | 没有可信更新链 | 已签名仓库，或签名软件包加成文的密钥处理 | 安装更新时校验签名，而不只是 checksum |
| P1 | 强制更新未生效 | Linux 客户端标识和策略服务合同，或明确的豁免 | 策略要么阻断过期客户端，要么豁免被记录并测试 |
| P1 | 缺少更新提醒 | 带紧急级别的 freedesktop 通知或启动器角标 | 在别的虚拟桌面也能注意到已准备好的更新，而不需要聚焦窗口 |
| P1 | 命令行管理没有 Linux 界面 | 在 Linux 显示现有菜单项并调整文案 | 从菜单完成安装、修复和移除，PATH 上留下可用的 `dsh` |
| P1 | 全屏隐藏未验证 | 平台分支和会话测试 | X11 与 Wayland 都能干净退出全屏并恢复同一文档 |
| P1 | 没有真实桌面验收 | 物理或虚拟 X11 与 Wayland 会话 | 记录焦点、拖拽、缩放、覆盖层、通知、托盘、深链和更新提示 |
| P2 | 缺少文件拖拽和新文件动作 | 开发线的共享文件拖拽与 Host 资源 API | 从工作区拖出的文件生成可校验临时文件并完成清理 |
| P2 | 缺少计算机操作 | Linux 控制与无障碍实现 | X11 与 Wayland 下可观察和输入，并覆盖拒绝与撤销授权 |
| P2 | 分发覆盖窄 | 每个目标各自的打包和运行时工作 | Linux arm64 和至少一种非 deb 格式通过各自安装门禁 |

## 尚未进入官方版本的开发线

官方 `dsh-v0.2.1-rc.5` 基线不是最新源码。上游 `dsh-v0.2.2-alpha.2` 增加了移植版尚未携带的桌面文件，应把它们当作计划中的回移，而不是官方版本缺少的功能。

| 开发线功能 | 新增内容 | 移植状态 |
| --- | --- | --- |
| 插件操作历史 | 管理器生命周期事件、有界记录和隔离报告 Worker | 补丁 0009，等待验证运行和发布 |
| 原生文件拖拽 | 限定在产品主 frame 与活动 Host 的校验复制拖拽 | 未回移 |
| 更新窗口 | 独立更新窗口和修订后的覆盖层行为 | 补丁 0007 的附着式对话框已部分具备 |
| 语言缓存 | 带变更通知的桌面语言缓存 | 未回移 |

文件拖拽和操作历史都依赖共享的 Host 与客户端 API，只回移桌面一半会留下死代码。要么把移植版 rebase 到更新的非 alpha tag，要么把 provider、消费者和生命周期一起携带。

## 有意的差异

- Linux 移植版增加了 macOS 没有的能力：托盘、PolicyKit 安装、固定 SCNet Bundle 及配置与诊断、Secret Service 适配器和离线运行时包。
- Linux 使用窗口控件覆盖层或桌面原生边框，而不是红绿灯和毛玻璃。这是明确的外壳选择，不是缺失的补丁。
- Windows 关闭最后一个窗口即退出；Linux 跟随 macOS 生命周期，让后台任务继续。这会改变退出路径，需要单独验收。
- 在上下游接受 Linux 之前，账户和内嵌 Platform 标识仍是 macOS 回退值。不要把一次本地账户请求成功当作 Linux 账户支持已完成的证据。

## 验证边界

Linux 验证 workflow 证明补丁应用、类型检查、定向回归、deb 构建、SCNet 内容完整性和 Ubuntu 24.04 上安装后的无头会话，不证明真实合成器行为。已发布字节验证、升级、AppArmor、Wayland 和 Debian 13 仍是手动 job。标记为已实现的条目描述源码及其测试；标记为待开发的条目描述尚未在 Linux 桌面运行过的工作。

## 参考资料

- [固定的上游基线](../ci/upstream-base-tag)
- [Linux 验证 workflow](../.github/workflows/linux-desktop-verify.yml)
- [桌面功能跟进](DESKTOP-FOLLOWUP.zh-CN.md)
- [Linux 构建与验收指南](../LINUX-DESKTOP.zh-CN.md)

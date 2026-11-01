[English](DESKTOP-PARITY.md) | 中文

# 桌面平台能力对齐

本文对照官方 macOS 桌面版本与本仓库 Linux 移植版的桌面能力。它是一份带证据的现状清单，不表示两个平台的行为已经完全一致。

## 范围与证据

官方基线是上游 `dsh-v0.2.1-rc.5`，也就是发布 macOS 和 Windows 桌面外壳的版本。Linux 侧以 `patches/` 中的活动补丁系列和已发布的 `v0.2.1-rc.5-linux.2` 包为准，该包由这一系列构建。发布树的哈希与当前系列一致，源码与发布不再分离。上游 `dsh-v0.2.2-alpha.2` 是开发线，其功能不属于正式版。

## 对正式版的结论

`dsh-v0.2.1-rc.5` 的每一项桌面外壳能力在 Linux 上都有实现或明确的平台对应实现，且 `v0.2.1-rc.5-linux.2` 与当前系列由同一补丁树构建（补丁树 `0fef55a99edf4a7f857ab0365c98644bce9d7fff`）。缺口表中剩余的行按明确的项目决定不属于正式版对齐范围：平台固有集成（Dock、毛玻璃、公证和官方强制更新身份）、实验性 CUA provider、发行面广度，以及只存在于上游开发线的功能。真实桌面上的交互确认属于验证工作，而不是缺失功能。

每一行的证据来自固定上游树和 `apply.sh` 生成的补丁树。最有用的文件是 `apps/desktop/src/main.ts`、`apps/desktop/src/windows-layout.ts`、`apps/desktop/src/platform-view.ts`、`apps/desktop/src/update-attention.ts`、`apps/desktop/src/command-management.ts`、`apps/desktop/scripts/electron-builder-config.mjs`，以及验证 workflow 运行的定向桌面测试。只有测试或发布门禁实际执行过的能力才算已具备；类型检查和照抄一个菜单项不能作为平台证据。

## 能力矩阵

| 领域 | 官方 macOS 桌面 | Linux 移植版 | 仍需开发 |
| --- | --- | --- | --- |
| 窗口外观 | `hiddenInset` 标题栏、内嵌红绿灯、侧栏毛玻璃和透明背景 | 40 DIP 自绘标题栏与窗口控件覆盖层、本地化标题栏菜单，或使用 `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` 恢复原生边框 | 毛玻璃和半透明依赖合成器，尚未实现；标题栏配色是静态的 |
| 全屏 | 原生全屏、覆盖层标题栏留白，隐藏窗口前先退出全屏 | 全屏状态会转给渲染层处理留白，隐藏前也会像 macOS 一样先退出全屏 | 在真实 X11 和 Wayland 会话确认恢复路径 |
| 托盘与窗口恢复 | 没有菜单栏图标；Dock 图标和第二次启动恢复窗口 | 托盘 Open/Quit 加“显示窗口”菜单项；Dock 的等价物是启动器 | 托盘是否可用取决于桌面环境；没有扩展的 GNOME 只能靠重新启动 |
| 关闭与退出生命周期 | 关闭最后一个窗口后应用和任务继续运行 | 关闭最后一个窗口后 Host 和任务继续运行，与 macOS 一致而非 Windows | 在真实桌面确认隐藏窗口和 Host 能跨会话切换存活 |
| 更新提醒 | Dock 图标弹跳加系统通知 | 启动器角标加紧急级别通知，窗口获得焦点后清除 | 在目标桌面环境验证角标和通知行为 |
| 应用菜单 | File 菜单显示单键绑定、Edit、Window 和隐藏命令 | Application 与 Edit 自绘菜单加原生 Edit 菜单，并包含“管理 dsh 命令”；没有 File 和 Window 菜单 | 可选：补 Window 菜单和单键绑定提示；DOM 分发已经可用 |
| 终端命令 | 通过管理员授权安装到 `/usr/local/bin/dsh` | 通过随包启动器安装到 `~/.local/bin/dsh`；“管理 dsh 命令”可安装、修复和移除 | 在真实桌面验证安装、修复和移除；外来启动器会被备份而不是直接替换 |
| 目录选择器 | 附着在主窗口上的 Electron 文件夹对话框 | 上游在缺少 zenity 和 kdialog 时已经回退到浏览模式，移植版保留该行为 | 在真实桌面验证回退和附着对话框 |
| 深链 | 由应用包注册 `dsh://`、`open-url` 和 Launch Services | 桌面项声明 `x-scheme-handler/dsh`、`xdg-mime`，并由单实例命令行路由 | `xdg-mime query default x-scheme-handler/dsh` 必须指向已安装的桌面项；失效即打包缺陷 |
| 单实例 | 访问 profile 前先取得进程生命周期锁 | 同一把锁；无头会话测试覆盖普通重启和 `dsh://open` | 普通第二次启动的窗口断言需要真实桌面 |
| 麦克风 | 系统授权、用途说明和音频输入 entitlement | 只接受主应用 frame 的请求；非 macOS 请求直接放行，没有系统弹窗 | 验证 PipeWire 和 PulseAudio 采集，并决定是否需要 portal 授权流程 |
| 账户登录与内嵌 Platform | 可接受的桌面平台值是 macOS 和 Windows；上游的登录按钮仍禁用 | 移植版因 Linux 不是可接受值而传入 macOS 回退值 | 需要上游接受 Linux，才能提供真实的客户端标识、内嵌 Platform 视图或登录 |
| 更新 | 官方更新服务的签名产物，带渠道和强制更新策略 | 设置页和原生“检查更新”动作都从 GitHub release 发现更新，校验 Ed25519 签名的清单，并用 PolicyKit 安装重新构建的 deb；菜单会在安装前确认 | 如需硬性阻断，可把最低支持版本扩展成阻塞策略 |
| 强制更新策略 | 策略服务接受 Windows 和 macOS 标识 | 自有的 `desktop-policy.json` 最低支持版本会报告“必须更新”；对话框仍保留“稍后”，离线机器仍可使用 | 若需要硬性阻断，把该门禁移入 Host 启动流程 |
| 软件包签名 | Developer ID 签名与公证 | deb 本身未签名，但 `SHA256SUMS` 带 Ed25519 分离签名，应用在特权安装前会校验，并在同一 release 发布支持策略 | 若改用 apt 仓库，可对 deb 本身做包级签名而不只是签清单 |
| 打包目标 | macOS arm64 与 x64 镜像；Windows 安装器 | 只有 Linux x64 deb | Linux arm64、rpm、AppImage 和 Flatpak 需要各自的运行时与验收工作 |
| 沙箱与权限 | 强化运行时、entitlement 和 macOS 沙箱模型 | AppArmor 配置、SUID `chrome-sandbox` 回退，以及 bwrap 或 Landlock 沙箱用例 | 持续覆盖沙箱回退，并手动测试 Wayland 会话 |
| 开发者工具 | Command+Option+I 和隐藏菜单项 | F12、Ctrl+Shift+I、可见的中英文菜单项和原生快捷键 | 由定向键盘和菜单测试覆盖 |
| 崩溃恢复 | 报告写入 macOS 日志目录并显示原生对话框 | 报告写入 userData 日志目录，并可从设置菜单取回已保存报告 | 在真实桌面检查定位动作和十条报告保留策略 |
| 计算机操作 | 专用 macOS provider 使用辅助功能和屏幕录制权限 | 没有 Linux provider | 需要 X11 与 Wayland 的控制、无障碍树、截图和授权测试 |
| 原生文件拖拽与新文件动作 | 在开发线中，不在官方基线 | 固定基线中没有 | 按 [ADR-0003](roadmap/ADR-0003-file-drag-backport.zh-CN.md) 分阶段回移，先做 Wayland/X11 验证 |
| 插件操作历史 | 在开发线中，不在官方基线 | 已随 `v0.2.1-rc.5-linux.2` 发布；发布 job 会审计随包管理器和报告 Worker | 在真实桌面取回一次报告检查 |

## 需要开发的能力缺口

| 优先级 | 缺口 | 依赖 | 出口条件 |
| --- | --- | --- | --- |
| P1 | 强制更新未生效 | Linux 客户端标识和策略服务合同，或明确的豁免 | 策略要么阻断过期客户端，要么豁免被记录并测试 |
| P1 | 没有真实桌面验收 | 物理或虚拟 X11 与 Wayland 会话 | 记录焦点、拖拽、缩放、覆盖层、通知、托盘、深链和更新提示 |
| P2 | 缺少文件拖拽和新文件动作 | 开发线的共享文件拖拽与 Host 资源 API | 从工作区拖出的文件生成可校验临时文件并完成清理 |
| P2 | 缺少计算机操作 | Linux 控制与无障碍实现 | X11 与 Wayland 下可观察和输入，并覆盖拒绝与撤销授权 |
| P2 | 分发覆盖窄 | 每个目标各自的打包和运行时工作 | Linux arm64 和至少一种非 deb 格式通过各自安装门禁 |

## 尚未进入官方版本的开发线

官方 `dsh-v0.2.1-rc.5` 基线不是最新源码。上游 `dsh-v0.2.2-alpha.2` 增加了移植版尚未携带的桌面文件，应把它们当作计划中的回移，而不是官方版本缺少的功能。

| 开发线功能 | 新增内容 | 移植状态 |
| --- | --- | --- |
| 插件操作历史 | 管理器生命周期事件、有界记录和隔离报告 Worker | 已随 `v0.2.1-rc.5-linux.2` 发布 |
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

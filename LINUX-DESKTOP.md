# DeepSeek Harness Desktop — Linux（mac-like）移植补丁集

> 本文档对应的 Linux x64 路径已在本机实际编译、打包并启动验证。验证产物为 AppImage
> 和 deb；当前主机缺少 `libfuse.so.2`，AppImage 使用自解压运行模式完成启动检查。
> 另在 **ubuntu-24.04 与 Debian 13（trixie）** 的 GitHub Actions（workflow
> `Linux desktop verification`）上完整跑通。最新一轮是**13 个补丁**的完整门禁集
> （run `37411910000`，2026-10-06，head `d70585e`）：8 个 job 中 7 个绿，涵盖
> `install + typecheck + package preflight`、打包、Debian 13、deb 升级路径与硬化启动、
> 已发布产物校验与 Wayland 冒烟；唯一报红的是上游门禁聚合腿，且在同一次运行的
> **未打补丁基线 tag** 上挂的是同样两个任务、同样四个测试，与本补丁集无关。
> 更早的一轮（run `36982274054`，当时 9 个补丁）即已跑通 `pnpm install` →
> `pnpm run typecheck` → 应用构建 → `check:package` → `package:linux:x64:dir` →
> 产物体检 → 无头 runtime 冒烟 → Xvfb GUI 冒烟 → AppImage + deb。

> 基线：上游 `deepseek-ai/deepseek-harness` tag **`dsh-v0.2.0-rc.2`**（commit `639ed0153972`）。
> 目标：在 Linux x64 上得到与 macOS 版**行为一致**的 Electron 桌面壳，产物为 AppImage + deb。
> 性质：非官方补丁集。上游 README 明确写有 “Linux is not a supported Desktop release target”，
> 且打包脚本的测试断言 `linux-x64` 必须被拒绝 —— 本补丁集就是把这层限制打开并把 Linux 路径补齐。

## 0. 结论速览

- **能做到 mac 一致的**：同一套 UI/后端、原生窗口、关掉最后一个窗口不退出、`dsh` 命令进 PATH、
  `dsh://` 深链唤回、菜单与快捷键、自建/关闭更新、Office 走内置 WASM 引擎。
- **物理上做不到 1:1 的**：窗口左上角红绿灯（`hiddenInset` 是 macOS 专属）、侧栏 vibrancy 毛玻璃、
  Dock 图标跳动提醒。这三项在补丁里用等价物替代（overlay 原生窗口控件 / 纯色侧栏 / 通知）。

## 1. 构建前置

| 项 | 要求 |
|---|---|
| 构建机 | Linux **x64**（本补丁集只加 `linux-x64`；arm64 见 §6 后续项） |
| Node | `^22.19 \|\| >=24`（上游 CI 用 Node 24） |
| pnpm | `11.7.0`（`package.json` 的 `packageManager`；`corepack enable` 最省事） |
| 本地环境文件 | 打包前**必须**存在 `apps/desktop/.env.linux`：读不到会直接抛 `cannot read … copy … .example`。`apply.sh` 会自动从模板生成 |
| 系统包 | `rpm`/`fpm` 视目标而定（deb 需要 `dpkg`/`fakeroot`）；AppImage 需要 `libfuse2`（仅运行旧内核） |
| 图形依赖 | 构建不需要 GUI；**验证**需要 X11/Wayland，或 `xvfb-run` |
| LibreOffice | **不需要安装**：Linux 走随包内置的 WASM 引擎（见 §5） |
| 字体 | 若在极简容器里跑，WASM 引擎只用导入的字体；无字体时转换会以 `unavailable` 拒绝，需要装字体或配置 `fontDirectories` |

## 2. 应用补丁集

```sh
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
git checkout dsh-v0.2.0-rc.2
git checkout -b linux-desktop
git am /path/to/patches/*.patch        # 顺序即文件名顺序
cp apps/desktop/.env.linux.example apps/desktop/.env.linux   # 打包必需，先按默认值即可
pnpm install --frozen-lockfile
```

> 随补丁集附带的 `apply.sh` 把上面几步（克隆、切分支、`git am`、生成 `.env.linux`）一次做完：
> `./apply.sh [目标目录]`；加 `--install` 会在最后执行 `pnpm install --frozen-lockfile`。
> 它只准备源码树，**不会**编译或打包。

> 若某个 patch 因上游改动冲突：`git am --show-current-patch=diff` 看上下文，
> 手工合入后 `git add <路径> && git am --continue`。补丁只触及 `apps/desktop/`、
> 根 `scripts/` 与少数 `packages/` 文件，冲突面很小。

## 3. 打包

```sh
# 先出目录产物（最快，用来确认能不能启动）
pnpm --dir apps/desktop run package:linux:x64:dir

# 再出 AppImage + deb
pnpm --dir apps/desktop run package:linux:x64
```

（脚本名以补丁实际加入的 `apps/desktop/package.json` 为准；若上游已有 `package` 通用入口，
也可用 `pnpm --dir apps/desktop run package`。）

## 4. 验收清单（7 条 mac parity）

补丁集按这 7 条设计，逐条在 Linux 上验：

1. **启动**：打包版能起来，不抛 `desktop policy: unsupported platform`，能进入工作区。
2. **窗口观感**：无系统标题栏、原生窗口控件在右上角（`titleBarOverlay`）；出问题用
   `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` 回退到原生边框。
3. **生命周期像 mac**：关掉最后一个窗口后应用**不退出**，后台任务继续；菜单里能重新打开窗口；
   显式 Quit 能真正退出。
4. **CLI 进 PATH**：安装/卸载 `dsh` 命令后，新开 shell 能直接跑 `dsh --version`；
   已存在非本应用的同名命令时应报告冲突而不是覆盖。
5. **深链**：`xdg-open 'dsh://...'` 能唤回并聚焦应用（deb 安装后生效；AppImage 需桌面项已注册）。
6. **内置运行时**：`Resources/runtime/primary-runtime/dependencies/{node,pnpm,python}` 是 Linux 版，
   agent 能跑 bash 工具、Office 技能能跑 python 脚本。
7. **更新策略**：默认不联网检查更新（无官方 Linux feed）；设了
   `DSH_DESKTOP_LINUX_UPDATE_ORIGIN` 才启用自建 feed。

## 5. 已知限制与坑

- **Office 技能不需要系统 LibreOffice**（这一点容易搞反）：npm 上确实**没有**
  `@deepseek-ai/libreoffice-kit-linux-x64`，但上游为 Linux 准备的是 **WASM 引擎**：
  - `scripts/libreoffice-engine.spec.ts` 断言 `linux x64/arm64 → 'wasm'`（上游已测试的契约）；
  - `scripts/libreoffice-packages.mjs` 在原生包未声明时回退 `wasm`；
  - `@deepseek-ai/libreoffice-kit-wasm`（npm `os: ['linux']`，含 `assets/soffice.wasm|soffice.data`）
    是 wrapper `@deepseek-ai/libreoffice-kit` 的 `optionalDependencies`，Linux 上 pnpm 会自动装；
  - 随包分发的 Office 技能文档明确**禁止**调用系统 `soffice`。
  所以不要在补丁里加"系统 soffice"分支（会是永不触发的死代码，且与技能契约冲突）。
  唯一要注意的是**字体**：WASM 引擎只用导入的字体，极简容器无字体时转换会拒绝执行。
- **原生依赖 Linux 可用性（已核实）**：
  - `node-pty`：npm tarball 内含 `prebuilds/linux-x64/pty.node` 与 `linux-arm64`，不需要编译工具链。
  - `node-addon-require-builtin`：Linux 版按 libc 分（`-linux-x64-gnu` / `-musl`），包元数据声明 `libc`，
    由包管理器自动选；**不要**手工按 libc 裁剪。
  - `@img/sharp-linux-x64`、`@koromix/koffi-linux-x64`、`@vscode/ripgrep-linux-x64`、
    `@deepseek-ai/node-addon-system-linux-x64`、`sherpa-onnx-linux-x64`：均存在，且都声明了
    `os`/`cpu`（koffi/ripgrep 另声明 `libc`），`pnpm install --prod` 在 Linux 上只会装对应变体。
    Linux 包内同时带 glibc 与 musl 两份（koffi 的 `linux_x64/`+`musl_x64/`、node-addon-system 的
    `bin/glibc|musl/`），**不要**裁剪掉其中一份。
  - `primary-runtime` 的 Linux 表项上游已有：Node `node-v24.21.0-linux-{x64,arm64}.tar.gz`、
    Python `cpython-3.12.14+…-linux-gnu-install_only_stripped.tar.gz` 的 sha256 已与
    nodejs.org / astral 的校验文件核对一致。
- **Ubuntu 23.10+ 的 AppArmor 限制**：未特权 user namespace 受限时，Electron/AppImage 的沙箱可能
  起不来（典型报错与 `chrome-sandbox` 相关）。**优先用 deb**（自带 setuid 沙箱助手），
  AppImage 走不通时再考虑 AppArmor profile 或 `--no-sandbox`（会降低安全性，仅作兜底）。
- **bash 沙箱**：Linux 侧走 Landlock（`@deepseek-ai/node-addon-system-linux-*`）。首次运行请确认
  内核 ≥ 5.13，否则沙箱策略会退化，需要按提示调整策略配置。
- **托盘**：mac 版没有托盘，补丁**不给 Linux 加托盘**（GNOME 下 AppIndicator 也不可靠）；
  窗口关掉后用菜单/再次启动唤回。
- **自动更新**：官方 feed 只有 `mac-arm64` / `mac-x64` / `win-x64`。Linux 默认关闭；
  自建 feed 时按 electron-updater 的 generic provider 放 `latest-linux.yml` + AppImage 产物。
  另外 **Linux 下的"强制更新 policy"是惰性的**：共享身份模型与 `x-client-platform`
  只有 `web`/`darwin`/`win32`，没有 Linux 取值，因此补丁让 Linux 显式跳过整套 policy
  （不构造强制更新窗口、不检查）；manifest 里仍带着 `dshMandatoryUpdatePolicy` 也不会拦启动。
- **CLI 进 PATH 只在 deb 下可用**：AppImage 的资源目录在临时挂载点，应用退出即失效，
  所以补丁在 AppImage 里**拒绝**安装 `dsh` 命令并给出提示（逃生口 `DSH_DESKTOP_RESOURCES`，
  用于解包后的稳定目录）。要"和 mac 一样有 `dsh` 命令"，请装 deb。
- **平台身份上报**：Linux 打包版向 DeepSeek Platform 上报的桌面身份沿用 macOS 分支
  （`x-client-platform: darwin`）。原因：共享账号包只定义了 `darwin`/`win32`，省略则退化成
  `web`。这会让服务端把你的客户端当成 macOS 客户端——若在意统计/服务端策略，需要先在上游
  共享包里定义 Linux 身份再改这一处。
- **安装器元数据**：Linux 可执行名使用 Debian 兼容的 `deepseek-harness`，展示名称仍为
  `DeepSeek Harness`；deb 的 `maintainer` 目前是 `DeepSeek Harness` 占位，建议换成你自己。
- **两处已知观感差异**：welcome 窗口的标题栏配色只在创建时跟随系统主题（Linux 没有 Windows 的
  palette 通道）；`<html data-windows-titlebar>` 这个属性名沿用了 Windows 叫法（改名会牵动
  packages/client 的 CSS 与测试，故保留）。
- **Linux 打包跳过了一项冒烟**：`smoke-packaged-runtime.ts` 只认 mac/win 的应用布局，
  补丁对 Linux 显式跳过它（`afterPack` 里的 `verifyDesktopRuntime` 仍会校验打包运行时）。

## 6. 后续（本补丁集未做）

- `linux-arm64` 目标（脚本结构与 Linux x64 相同，主要是原生包与 Node/Python 归档换架构）。
- 自建更新 feed 的完整流水线（签名不需要，但需要静态托管与 `latest-linux.yml` 生成）。
- 桌面环境的个性化适配：GNOME/KDE 下的窗口控件位置、Wayland 下的全局快捷键差异。
- `smoke-packaged-runtime` 的 Linux（AppImage/deb）布局；`desktop-toolchain-preflight` 目前
  对 Linux 复用通用探测（tar 等），未加 deb/AppImage 专用工具探测。
- Linux 侧新增测试：CLI launcher 的 Linux fixture 已补；PATH 提示文案与 `~/.local/bin`
  不在 PATH 时的警告未做。

## 7. 本补丁集仍未验证什么

本机已经完成 Linux x64 编译、runtime 准备、AppImage/deb 打包和基础启动验证；ubuntu-24.04 CI
另外把 **deb 安装/运行/卸载**、**AppImage 无 FUSE 启动**和**桌面测试套件基线**也跑完了。
以下项目仍需要在目标桌面环境上确认：

- 桌面环境相关的窗口控件观感；
- 托盘/通知等在真实桌面会话里的表现（CI 只覆盖打包后的运行时，不覆盖正在运行的桌面）。

已在 CI 中确认：安装 deb 后 `xdg-mime query default x-scheme-handler/dsh` 返回
`deepseek-harness.desktop`，`/usr/bin/deepseek-harness` 经 `update-alternatives` 指向
`/opt/DeepSeek Harness/deepseek-harness`，命令管理器装出的 `~/.local/bin/dsh` 可直接跑
`dsh --version`（输出 `0.2.0-rc.2`），卸载后无残留。桌面测试套件在 Linux 上
**128 个文件 123 个通过**（1357 passed / 58 skipped），唯一失败的
`apps/desktop/tests/macos-notarization-proxy.spec.ts` 守的是 macOS 专属功能
（`proxy recovery requires macOS`），其 `flock` 插件在 Linux 上不构建 —— 属预期的基线差异。

**上游自己的 Linux 门禁**（`pnpm run check:ci:linux-primary`，run `37042752808`；串行 + 装好
Playwright 浏览器）：打过补丁 78/80 通过，未打补丁的上游 tag 同样设置下 79/80。剩下两项都不是
本补丁集引入的：

- `web browser snapshot`：在**未打补丁**的 tag 上同样失败 —— 浏览器装上了，但 runner 缺它们依赖的
  系统库（`Host system is missing dependencies to run browsers`）。
- `scripts/persistence-schema.spec.ts` 里 1 个 flaky 用例（该文件本补丁集从未改动）：基线那轮通过，
  多次运行的失败数在 0/1/8 之间波动。

`patches/0012` 修掉了其中**属于我们**的两处门禁失败：4 个 oxlint 风格错误（单引号、内联类型分号）
和 `apps/desktop/LINUX.md` 里的 commit-hash 引用（`verify-repository-references` 只接受 tag/长期链接）。

**沙箱与 agent 工具调用**（同样在 CI 里真实执行）：

- 沙箱两条腿分别**真跑**（不是自跳过）：bwrap 腿 2 个文件通过、Landlock 腿 2 个文件通过 —— Landlock
  用例会强制关掉 bwrap 档位，所以每条腿各自证明一种机制。
- 无凭据 agent 回合：`apps/cli/tests/profiles/headless/tests/keyless-smoke.e2e.ts` 启动**真 Loader**、
  跑**生产 bash 工具**，断言 `tool/call → tool/result`（`CLI_TOOL_ROUND_TRIP`）并把回合以 zstd JSONL
  落盘。
- 打包链自带的运行时冒烟另外覆盖了：PTY、FFI(koffi)、sharp、ripgrep、glob、随包 pnpm 与 Python，
  以及把 `PATH` 清空后用随包 Office 引擎做真实的 DOCX/XLSX/PPTX→PDF 转换。

**真桌面会话**（`ci/desktop-session.sh`，run `37089025040`：Xvfb + openbox + dbus session，
驱动**已安装的 deb**）：

- 窗口**真的被创建并映射**（`DeepSeek Harness`，1288x824；另有 10x10 的托盘辅助窗口被显式排除）；
- **关掉最后一个窗口不会结束应用**（mac 一致性），进程与 Host 继续存活，Host 端点仍在应答；
- `xdg-mime query default x-scheme-handler/dsh` → `deepseek-harness.desktop`，
  用 `gio launch` 以 `dsh://open` 激活该条目时**窗口被唤回**；
- 之后的普通启动被单实例锁路由到运行实例，不会新起第二个进程。

这个"关窗→唤回"循环**两条路径都已修好**：`dsh://` 激活路径由 `patches/0013` 修复（激活要求窗口时，
若重建后的窗口仍是隐藏状态就把它显示出来），已于 run `37491323328` 的三处 `ci/desktop-session.sh`
会话复验成功（均报告 `the dsh:// activation brought the window back`）；**普通第二次启动路径**由
`patches/0014` 修复——它收窄了 `focusPrimaryWindow` 里的 early-return，让单实例锁路由回来的二次启动
把窗口重新显示，而不是只剩 10x10 托盘窗口。`ci/desktop-session.sh` 对两条路径都做断言，窗口若找不回
会让该 run 失败（见下"待CI 复验"）。

**真实桌面已确认**：在 Xfce/X11 桌面会话上针对已安装的 `…linux.3` deb 实测，两条路径都通过，其中
普通二次启动连跑三轮均成功唤回窗口。CI 的 headless（Xvfb）环境从未把第二条断言报绿——那是headless
环境的性质，不是补丁的问题。

**Linux 上的托盘此前是缺失的**：上游 `main.ts` 把 `DesktopTray` 整个包在 `process.platform === 'win32'`
里，Linux 上从不创建托盘。于是"关掉最后一个窗口后应用继续驻留"这条设计在没有托盘的系统上等同于
"进程活着但无法唤回"。`patches/0016` 在 Linux 上启用托盘，并随包投放 `tray.png`（StatusNotifier 面板
按主题自选尺寸，不能用 Windows 的多尺寸 ICO）。同一补丁还修了 dock 上的问号图标：
`StartupWMClass` 原本由 `productName` 推导成 `DeepSeek Harness`，而窗口实际报告的 `WM_CLASS` 是
`deepseek-ai-dsh-desktop`，面板匹配不上就显示问号。

本次验证覆盖的运行时检查与仍建议确认的项目（标 ✅ 的在上述 ubuntu-24.04 CI 中已确认）：

1. ✅ `@electron/get` 拉到的 `electron-v44-linux-x64.zip` 解包后，根目录二进制是否确实叫 `electron`
   （`prepare-runtime.ts` 的 Linux 分支按此假设；改名只影响这一处）。
2. ✅ `pnpm install --prod` 之后，Linux 运行时树里确实有 `@deepseek-ai/libreoffice-kit-wasm`、
   `node-addon-system-linux-x64`、`koffi-linux-x64`、`sharp-linux-x64`、`ripgrep-linux-x64`、
   `sherpa-onnx-linux-x64`，且没有 darwin/win32 残留（`resources/runtime/pnpm` 里 pnpm 自带的
   跨平台 vendored 文件除外 —— 已发布的 macOS 版里同样存在）。
3. ✅ `prepare:dsh` 的 `runtime:materialize-modules` 之后，WASM 引擎的 `prebuilds.json` 是否在位，
   以及 `officePackageDirectories` 是否把 `libreoffice-kit-wasm` 目录正确加进 `asarUnpack`。
4. `~/.local/bin` 是否在你的 PATH 里（不在的话装上也不会生效，本期不额外提示）。
5. 桌面测试套件：`cli-launcher.spec.ts` 等文件原本按"非 win32 即 darwin"搭 fixture，仓库也从未把
   Linux 当发布目标，所以在 Linux 主机上跑测试**可能存在基线失败**。建议先在未打补丁的 tag 上跑一遍
   留基线，再对比补丁后的失败集合。

两条与冒烟直接相关的结论（都是首轮 CI 暴露、已修）：

- 仓库级 `pnpm run typecheck` 在 Linux 上首次真跑就失败：`apps/desktop/tests/installer-packaging.spec.ts`
  第 88–90 行三处 `TS2339`（`DesktopElectronBuilderConfig` 上没有 `linux` / `deb`）。
  手写声明 `apps/desktop/electron-builder.config.d.mts` 没跟着 Linux 目标扩展，`patches/0009` 补上后通过。
- dsh payload **在 `app.asar` 内部**（`asarUnpack` 只放 `.node`/`.so`、ripgrep、libreoffice-kit、
  landlock-run）。因此**不能用 shell 的 `test -f` 去戳 `app.asar/dsh/...`**，那必然报缺失；
  正确做法是把 asar 路径交给随包的 Electron（它给 `fs` 打了 asar 补丁），
  `ELECTRON_RUN_AS_NODE=1 <launcher> --expose-internals <app.asar>/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js --version`
  在 ubuntu-24.04 上输出 `0.2.0-rc.2`、退出码 0。

[English](README.md) | 中文

# deepseek-harness-linux-desktop

给 **DeepSeek Harness 桌面端** 补上 Linux x64 发布目标（`AppImage` + `deb`），并使其行为与
macOS 版保持一致的非官方补丁集。

上游只发布 macOS 与 Windows —— 其 `apps/desktop/README.md` 明确写着 Linux 不是受支持的桌面
发布目标，打包测试也断言 `linux-x64` 目标必须被拒绝。本仓库就是把这层限制打开的那组 diff。

> **状态：Linux x64 已在 GitHub Actions 的 Ubuntu 24.04 LTS 与 Debian 13（trixie）上验证通过，本机亦通过。**
> 十三个补丁干净应用到上游 tag，并在 Ubuntu 24.04 x86_64 上完成编译、打包与冒烟；
> 完整链路（含安装 deb 与启动 AppImage）也在 **Debian 13** 容器里跑通。
> 产物为 AppImage 与 deb；因作者本机没有 `libfuse.so.2`，AppImage 也以自解压模式启动过。
> `patches/0009`–`0012` 修的都是第一次真机/真 CI 跑出来的问题：typecheck 里的 `TS2339`、
> 找不到 payload 的 `dsh` 启动器、丢掉了 environment 的 upload-plan 报错文案，以及四处会被
> 上游自有 Linux 门禁拒绝的风格/仓库引用错误。

基线：上游 tag **`dsh-v0.2.0-rc.2`**（commit `639ed0153972`），13 个补丁。

---

## 目录

- [1. 你得到什么](#1-你得到什么)
- [2. 环境要求与固定路径](#2-环境要求与固定路径)
- [3. 构建 —— 一键脚本](#3-构建--一键脚本)
- [4. 构建 —— 分步（含成功判据）](#4-构建--分步含成功判据)
- [5. 验收清单（7 条行为）](#5-验收清单7-条行为)
- [6. 产物与落地位置](#6-产物与落地位置)
- [7. 失败排查](#7-失败排查)
- [8. 已验证 / 未验证](#8-已验证--未验证)
- [9. 已知限制](#9-已知限制)
- [10. 目录结构、许可与署名](#10-目录结构许可与署名)

---

## 1. 你得到什么

| # | macOS 行为 | 本补丁集在 Linux 上如何实现 |
|---|---|---|
| 1 | 应用能启动 | 桌面策略门禁不再在 Linux 上抛 `desktop policy: unsupported platform` |
| 2 | 窗口外观 | `titleBarStyle: 'hidden'` + `titleBarOverlay`（与 Windows 同一机制），标题栏区域交给页面；`DSH_DESKTOP_LINUX_NATIVE_FRAME=1` 可恢复系统边框 |
| 3 | 关掉最后一个窗口后任务继续跑 | `window-all-closed` 现在只在 Windows 退出；应用与其 Host 继续存活，菜单里的 Show Window 可把窗口找回来 |
| 4 | `dsh` 命令进 `PATH` | 新增 POSIX 启动器 + 命令安装器的 Linux 分支（`~/.local/bin/dsh`）；已有外来命令会被报告并备份，绝不静默覆盖 |
| 5 | `dsh://` 深链 | desktop 条目带 `MimeType=x-scheme-handler/dsh`；shell 侧已完成协议注册 |
| 6 | 内置运行时 | runtime 准备按**目标**平台选择 Linux payload（Node/pnpm/Python、Electron 二进制、原生包），不再假定 macOS 或 Windows |
| 7 | 更新 | Linux 包默认无更新源；设置 `DSH_DESKTOP_LINUX_UPDATE_ORIGIN` 可接入自建 generic（AppImage）源 |

Office 文档转换开箱可用：Linux 走**内置 WASM** LibreOffice 引擎
（`@deepseek-ai/libreoffice-kit-wasm`），**不需要**系统安装 LibreOffice。

## 2. 环境要求与固定路径

**构建机必须是 Linux x86_64。** 补丁保留上游规则：`linux-x64` 目标拒绝在其它平台构建，
因此无法从 macOS 交叉编译。本系列只覆盖 `linux-x64`，不含 `linux-arm64`。

| 要求 | 取值 | 检查 |
|---|---|---|
| 主机 | Linux x86_64 | `uname -sm` → `Linux x86_64` |
| Node | `^22.19.0 \|\| >=24.0.0` | `node -v` |
| pnpm | `11.7.0` | `corepack enable && pnpm -v` |
| git | 任意较新版本 | `git --version` |
| 磁盘 | ≥ 15 GB（checkout ≈ 200 MB，依赖 + Electron + 运行时 payload 数 GB） | `df -h "$HOME"` |
| 网络 | `registry.npmjs.org`、`nodejs.org`、Python standalone 构建、`github.com`（Electron）、electron-builder 自身下载 | 取决于代理，见排查表 |
| 冒烟所需显示 | X11/Wayland，或 `xvfb-run` | `echo "$DISPLAY$WAYLAND_DISPLAY"` |

本文档后续使用的路径，先设好：

```sh
export PATCH_REPO="$HOME/src/deepseek-harness-linux-desktop"   # 本仓库
export SRC="$HOME/src/deepseek-harness"                        # 上游 checkout（下一步创建）
export TARGET_DIR="$SRC/apps/desktop/.desktop-build/targets/linux-x64"
export ARTIFACTS="$TARGET_DIR/artifacts"
```

## 3. 构建 —— 一键脚本

Agent 可以直接执行下面这段（任何断言失败即中止）：

```sh
set -euo pipefail

# --- 预检 -----------------------------------------------------------------
[ "$(uname -s)" = "Linux" ] || { echo "FAIL: host is not Linux"; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "FAIL: host is not x86_64"; exit 1; }
command -v git >/dev/null || { echo "FAIL: git missing"; exit 1; }
command -v node >/dev/null || { echo "FAIL: node missing"; exit 1; }
corepack enable >/dev/null 2>&1 || true
[ "$(pnpm -v)" = "11.7.0" ] || echo "WARN: pnpm is $(pnpm -v), expected 11.7.0"

export PATCH_REPO="${PATCH_REPO:-$HOME/src/deepseek-harness-linux-desktop}"
export SRC="${SRC:-$HOME/src/deepseek-harness}"

# --- 取补丁集并应用 --------------------------------------------------------
[ -d "$PATCH_REPO/.git" ] || git clone https://github.com/lql341/deepseek-harness-linux-desktop.git "$PATCH_REPO"
sh "$PATCH_REPO/apply.sh" "$SRC"

# --- 证明补丁确实落地 ------------------------------------------------------
[ "$(git -C "$SRC" rev-parse HEAD^{tree})" = "1bc46010b3ecd920638bd625a55957e71f07269a" ] \
  || { echo "FAIL: patched tree hash mismatch"; exit 1; }
[ -f "$SRC/apps/desktop/.env.linux" ] || { echo "FAIL: .env.linux missing"; exit 1; }

# --- 依赖 ------------------------------------------------------------------
cd "$SRC"
pnpm install --frozen-lockfile

# --- 廉价预检：校验 .env.linux 与构建工具链 --------------------------------
pnpm --dir apps/desktop run check:package     # 期望: "would publish 0.2.0-rc.2 ... valid"

# --- 先出目录产物：能不能起来 ----------------------------------------------
pnpm --dir apps/desktop run package:linux:x64:dir

# --- 再出真正的产物 --------------------------------------------------------
pnpm --dir apps/desktop run package:linux:x64
ls -l "$SRC/apps/desktop/.desktop-build/targets/linux-x64/artifacts"
```

## 4. 构建 —— 分步（含成功判据）

### Step 0 —— 主机预检

```sh
uname -sm          # 期望: Linux x86_64
node -v            # 期望: v22.19+ 或 v24+
corepack enable && pnpm -v   # 期望: 11.7.0
df -h "$HOME"      # 期望: >= 15G 可用
```

若 `uname -m` 是 `aarch64`，或 `uname -s` 是 `Darwin`，到此为止：本补丁集不覆盖该组合。
在 macOS 上仍可应用补丁（step 1 与平台无关），但 `package:linux:x64` 会拒绝执行。

### Step 1 —— 克隆本仓库并应用补丁序列

```sh
git clone https://github.com/lql341/deepseek-harness-linux-desktop.git "$PATCH_REPO"
sh "$PATCH_REPO/apply.sh" "$SRC"
```

`apply.sh` 会克隆上游 tag `dsh-v0.2.0-rc.2`、创建分支 `linux-desktop`、对全部 13 个补丁执行
`git am`，并把 `.env.linux.example` 复制为 `.env.linux`（打包代码要求该文件存在，缺了会直接报错）。

成功判据 —— 四条都要成立：

```sh
git -C "$SRC" log --oneline | head -1
#   期望: "fix(desktop): keep a window on screen when activation rebuilds it"
git -C "$SRC" rev-parse HEAD^{tree}
#   期望: 1bc46010b3ecd920638bd625a55957e71f07269a
git -C "$SRC" status --porcelain      # 期望: 空
test -f "$SRC/apps/desktop/.env.linux" && echo env-ok
```

想先审阅而不是直接相信：`git -C "$SRC" log --stat` 会显示这些主题提交。

### Step 2 —— 安装依赖

```sh
cd "$SRC"
pnpm install --frozen-lockfile
```

期望 exit 0。默认 registry 慢时可用镜像：在 `apps/desktop/.env.linux` 里设
`DSH_DESKTOP_NPM_REGISTRY`（供内置运行时安装使用），或设
`ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/`（供 Electron 下载）。

### Step 3 —— 廉价预检（不构建，几秒）

```sh
pnpm --dir apps/desktop run check:package
```

它会校验 `.env.linux`、发布设置与主机工具链，然后打印类似
`desktop package: linux-x64 would publish 0.2.0-rc.2; local configuration and toolchain valid`。
在花时间做真正的构建前，先把这里报的问题修掉 —— 这是最便宜的一处：pnpm 版本不对、
`.env.linux` 缺失或其中某项非法，都会在这里暴露。

### Step 4 —— 目录产物（第一次真正的构建）

```sh
pnpm --dir apps/desktop run package:linux:x64:dir
```

每个打包命令都会先自行构建整个仓库、准备 Electron 发行版、从 registry 安装生产运行时闭包，
再写出未打包的应用。耗时数分钟、输出很多；**exit 0** 即通过。

成功判据：

```sh
ls -d "$ARTIFACTS"/linux-unpacked                                    # 未打包应用
ls -l "$ARTIFACTS/linux-unpacked/DeepSeek Harness"                   # Electron 二进制，且有可执行位
```

### Step 5 —— AppImage + deb

```sh
pnpm --dir apps/desktop run package:linux:x64
ls -l "$ARTIFACTS"/*.AppImage "$ARTIFACTS"/*.deb
```

期望恰好两个产物，名字来自产品版本（见 §6）。Linux 不做签名/公证，这里没有别的步骤。

想要自己的编号可加 `--build-version`，例如
`pnpm --dir apps/desktop run package:linux:x64 -- --build-version 0.2.0-rc.2.linux.1`；
不加则产物沿用上游产品版本。

### Step 6 —— 冒烟

```sh
# 目录产物，无头主机：
xvfb-run -a "$ARTIFACTS/linux-unpacked/DeepSeek Harness"

# 或者装 deb（这也是让 dsh 命令可用的方式，见 §9）：
sudo apt install "$ARTIFACTS"/deepseek-harness-*-linux-amd64.deb
dpkg -L deepseek-harness | grep -E '/(bin|opt)/'    # 找到已安装的可执行文件
# 然后从桌面菜单启动，或运行上面打印的路径（注意加引号：路径里有空格）
```

头 30 秒要盯的点：

- 必须进到工作区/欢迎界面，且**不能**打印 `desktop policy: unsupported platform`；
- 窗口不应有系统标题栏，右上角是原生窗口控件（若桌面环境画得不对，用
  `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` 重试）；
- 在无 user namespace 的容器里，Chromium 沙箱可能拒绝启动 —— 优先用 `deb`，
  `--no-sandbox` 只作最后手段（会降低安全性）。

## 5. 验收清单（7 条行为）

按顺序执行；每条都对应 `patches/` 里的一个补丁。

| # | 检查项 | 命令 / 观察点 | 期望 |
|---|---|---|---|
| 1 | 能启动 | 按 step 6 启动 | 打开工作区，无 `unsupported platform` |
| 2 | 窗口外观 | 观察窗口；切换 `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` | overlay 标题栏 + 原生控件；该变量可恢复系统边框 |
| 3 | 关窗不退出 | 关掉最后一个窗口，然后 `pgrep -af "DeepSeek Harness"` | 进程仍在；菜单 Show Window 能把窗口找回；显式 Quit 才真正退出 |
| 4 | `dsh` 进 PATH | 在应用 UI 里安装命令，然后开**新** shell：`command -v dsh && dsh --version` | 落在 `~/.local/bin/dsh`，能跑内置 CLI（确保 `~/.local/bin` 在 `PATH` 里） |
| 5 | 深链 | `xdg-mime query default x-scheme-handler/dsh`，再 `xdg-open 'dsh://open'` | 已注册 desktop 文件且窗口被唤到前台 |
| 6 | 运行时 + Office | 在会话里跑一次 shell 工具；要求一次 DOCX→PDF 转换 | bash 工具可用（Landlock，内核 ≥ 5.13）；转换经内置 WASM 引擎成功 |
| 7 | 更新 | 不设 `DSH_DESKTOP_LINUX_UPDATE_ORIGIN` 启动 | 不检查更新；设置自建 generic 源后读取 `latest-linux.yml` |

## 6. 产物与落地位置

一切都写在 `apps/desktop/.desktop-build/targets/linux-x64/` 下：

| 路径 | 内容 |
|---|---|
| `artifacts/linux-unpacked/` | 未打包应用（来自 `:dir`）；可执行文件 `DeepSeek Harness` |
| `artifacts/deepseek-harness-<version>-linux-x86_64.AppImage` | AppImage |
| `artifacts/deepseek-harness-<version>-linux-amd64.deb` | Debian 包 |
| `runtime/` | 为该目标准备好的 Electron + pnpm + 启动器 |
| `dsh/` | 内置 `dsh` 运行时树，最终变成 `app.asar/dsh` |
| `package-set/`、`downloads/` | 中间包集合与已下载归档 |
| `packaging-runs/` | 每次运行的日志与发布记录 |

默认版本下即 `deepseek-harness-0.2.0-rc.2-linux-x86_64.AppImage` 与 `…-linux-amd64.deb`。

## 7. 失败排查

| 症状 | 原因 | 处理 |
|---|---|---|
| `desktop package: unsupported target "linux-x64"` | 补丁没打上 | 重跑 step 1，并核对树哈希 |
| `desktop package: cannot read …/.env.linux; copy …` | 必需的环境文件缺失 | `cp apps/desktop/.env.linux.example apps/desktop/.env.linux` |
| `desktop package: linux-x64 requires a Linux x64 build host` | 在 macOS/arm64 上构建 | 换到 Linux x86_64 |
| `desktop package: unsupported setting X in …/.env.linux` | 键不在 Linux 模板里 | 只用 `DSH_DESKTOP_APP_ID`、`DSH_DESKTOP_NPM_REGISTRY`、`DSH_DESKTOP_LINUX_UPDATE_ORIGIN` 及策略 origin |
| `ERR_PNPM_UNSUPPORTED_ENGINE` / 奇怪的依赖错误 | Node 或 pnpm 版本不对 | Node `^22.19 \|\| >=24`，pnpm `11.7.0` |
| Electron 下载超时 / 404 | 代理或镜像 | `ELECTRON_MIRROR`，或导出 `HTTPS_PROXY` |
| `missing required LibreOffice engine wasm` | 运行时树里没有 WASM kit | 确认 `@deepseek-ai/libreoffice-kit-wasm` 已安装（它是 `@deepseek-ai/libreoffice-kit` 的可选依赖） |
| `tsc` 在 `main.ts` 报类型错 | 第一次真类型检查 | 上报；最可能是策略分支的收窄 |
| AppImage 起不来（沙箱 / user namespace） | Ubuntu 23.10+ 的 AppArmor 限制 | 装 `deb`，或加 AppArmor profile；`--no-sandbox` 只作最后手段 |
| 安装 `dsh` 被拒：transient AppImage mount | AppImage 资源在临时挂载点 | 装 `deb`，或解出 AppImage 后设 `DSH_DESKTOP_RESOURCES` |
| 深链无反应 | desktop 文件未注册 | 确认 `xdg-mime query default x-scheme-handler/dsh`；重装 deb |

## 8. 已验证 / 未验证

已验证：

- 13 个补丁全部干净应用到 `dsh-v0.2.0-rc.2`；`git am` 后树哈希为
  `1bc46010b3ecd920638bd625a55957e71f07269a`，工作区干净、无残留改动。（该值按当前 13 个补丁
  重新测得；早先 12 个补丁时的 `5103892b735d996d9180605f73e5477bc84a894f` 已失效。）
- `apply.sh` 端到端跑通（含在 C locale、无 git 身份的机器上）：浅克隆 → 13 个补丁 →
  生成 `.env.linux` → exit 0。
- 每个改动文件都过语法检查；原生依赖都能在 npm registry 上解析到 Linux 变体
  （`node-pty` 自带 `linux-x64/arm64` prebuild）。
- `check:package` 通过；官方 Linux 构建的运行时准备、Office 文档往返、Electron 打包各阶段均通过。
- 产物为 `deepseek-harness-0.2.0-rc.2-linux-x86_64.AppImage` 与
  `deepseek-harness-0.2.0-rc.2-linux-amd64.deb`；deb 的元数据与内容已检查。
- Linux 安装器使用 Debian 安全的可执行名 `deepseek-harness`；其 `postinst` 用
  `update-alternatives` 注册该名字而非显示名，并在升级时清掉旧的
  `/usr/bin/DeepSeek Harness` 符号链接。
- deb 在 Debian/Ubuntu 上 `apt` 安装成功；dpkg 报 `install ok installed`，
  `/usr/bin/deepseek-harness` 经 alternatives 解析到预期位置。
- 打包后的应用能启动，并暴露本机 `dsh web` 端点。
- **ubuntu-24.04 上的 GitHub Actions**（workflow `Linux desktop verification`，
  dispatch run `37000258154`，2026-10-02）：干净 clone → 12 补丁 →
  `pnpm install --frozen-lockfile` → `pnpm run typecheck` → `apps/desktop` 构建 →
  `check:package` → `package:linux:x64:dir` → 产物体检 → 无头 runtime 冒烟 →
  Xvfb GUI 冒烟 → AppImage + deb → deb 安装/使用/卸载 → AppImage 启动 → 桌面套件基线，全绿。
- **deb 在 runner 上端到端可用**：`apt-get install` 报 `Status: install ok installed`；
  `update-alternatives` 把 `/usr/bin/deepseek-harness` 指向
  `/opt/DeepSeek Harness/deepseek-harness`；`xdg-mime query default x-scheme-handler/dsh`
  返回 `deepseek-harness.desktop`；已安装二进制以 Electron 44 / Node 24 运行；
  `resources/runtime/cli/bin/dsh --version` 输出 `0.2.0-rc.2`；命令管理器装出的
  `~/.local/bin/dsh` 可从 `PATH` 直接运行；删除命令与 `apt-get remove` 都不留残留。
  （`patches/0010` 是让启动器可用的关键 —— 没有它，每次都打印
  `dsh: the … payload is missing`。）
- **AppImage 无需 FUSE 即可启动**：`--appimage-extract-and-run`（也是 Ubuntu 23.10+ 的路径）
  在完整 40 秒窗口内持续提供 `dsh web: http://127.0.0.1:<port>`，且无
  `desktop policy: unsupported platform`；产物是 ELF 64-bit x86-64 可执行文件。
- **Linux 桌面测试套件基线**：128 个文件 123 个通过（1357 passed / 58 skipped）。唯一失败的
  `apps/desktop/tests/macos-notarization-proxy.spec.ts` 守的是 macOS 专属功能
  （`proxy recovery requires macOS`），其 `flock` 插件在 Linux 上不构建。此前失败的另两个文件
  —— `cli-launcher.spec.ts`（我们的启动器回归，由 `patches/0010` 修）与
  `desktop-upload-plan.spec.ts`（`patches/0011`）—— 现已通过。
- **上游自己的 Linux 门禁** `pnpm run check:ci:linux-primary`（run `37042752808`，串行 + 装好
  Playwright）：补丁树 78/80 通过，未打补丁的基线同参数下 79/80。剩下两项都不是本补丁集引入的：
  `web browser snapshot` 在未打补丁的 tag 上同样失败（浏览器装上了，但 runner 缺其系统库）；
  以及 `scripts/persistence-schema.spec.ts` 里 1 个 flaky 用例（本系列从未改动该文件），
  多次运行失败数在 0/1/8 之间波动。`patches/0012` 修掉了其中**属于我们**的两处门禁失败：
  4 个 oxlint 风格错误与一处被 `verify-repository-references` 拒绝的 commit-hash 引用。
- **沙箱在真内核上生效**：bwrap 腿（2 个文件）与 Landlock 腿（2 个文件）都通过，且断言它们
  **真的运行**而非自跳过 —— Landlock 用例会强制关掉 bwrap 档位，因此每条腿各证明一种机制。
- **一次无凭据的 agent 回合**：`apps/cli/tests/profiles/headless/tests/keyless-smoke.e2e.ts`
  在没有任何 API key 的前提下启动**真 Loader**、运行**生产 bash 工具**，断言
  `tool/call` → `tool/result` 往返（`CLI_TOOL_ROUND_TRIP`），并把该回合以 zstd JSONL 落盘。
  连同 `scripts/smoke-runtime.ts`，这在 Linux 上覆盖了工具链：PTY、FFI（koffi）、sharp、
  ripgrep、glob、内置 pnpm 与 Python，以及把 `PATH` 清空后用内置 Office 引擎做真实的
  DOCX/XLSX/PPTX→PDF 转换。
- 第一次真正的 Linux typecheck 曾让整个仓库失败（`pnpm run typecheck`，exit 2）：
  `apps/desktop/tests/installer-packaging.spec.ts` 三处 `TS2339` ——
  `DesktopElectronBuilderConfig` 上不存在 `Property 'linux'` 与 `Property 'deb'`。
  `electron-builder.config.d.mts` 这份手写声明没有随 Linux 目标扩展；`patches/0009` 补上后通过。
- 内置运行时能从归档内部应答：
  `ELECTRON_RUN_AS_NODE=1 <launcher> --expose-internals resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js --version`
  输出 `0.2.0-rc.2` 且 exit 0。payload 就在 **`app.asar` 内部**；`asarUnpack` 只放
  `.node`/`.so`、ripgrep、libreoffice kit 与 Landlock 启动器，所以用 shell 的 `test -f`
  去戳该路径永远不会成功。
- 未打包树里的 Linux 原生包齐全（`node-pty`、`sharp-linux`、`koffi-linux`、`ripgrep-linux`、
  `node-addon-system-linux`、`sherpa-onnx-linux`、`libreoffice-kit-wasm`），且
  `resources/runtime/pnpm` 之外没有任何 darwin/win32 残留。该目录是已发布 pnpm 包的逐字节拷贝，
  已发布的 macOS 版里同样带有这些跨平台 vendored 文件。
- 在 Xvfb 下 shell 能启动并提供本机端点（`dsh web: http://127.0.0.1:<port>`），
  无 `desktop policy: unsupported platform`。
- **真实桌面会话**（`ci/desktop-session.sh`，run `37089025040`；Xvfb + openbox + session bus，
  驱动已安装的 deb）：窗口被创建并映射（`DeepSeek Harness`，1288x824）；关掉最后一个窗口
  **不会**结束应用；`x-scheme-handler/dsh` 解析到包里的 `deepseek-harness.desktop`；
  用 `dsh://open` 激活该条目**能把窗口唤回**；之后的启动被路由到运行实例，而不是新起一个进程。
- **Debian 13（trixie），run `37091835014` 与 `37094351188` —— 全步通过。** 该 job 在
  `debian:13` 容器里从源码装 Node 24 与 pnpm 11.7.0、应用补丁、安装依赖、typecheck、跑打包预检、
  构建目录产物、冒烟内置运行时、打包 deb 与 AppImage、用 apt 安装 deb
  （`Status: install ok installed`；`/usr/bin/deepseek-harness` 经 `update-alternatives`）、
  把 `dsh://` 解析到 `deepseek-harness.desktop`、以 Electron 44 / Node 24 运行已安装二进制、
  用包内命令管理器安装并删除 `~/.local/bin/dsh`（`dsh --version` → `0.2.0-rc.2`）、
  跑与 Ubuntu 同一套真桌面会话（窗口被映射、关窗不退出、`dsh://` 激活能把窗口唤回、
  后续启动路由到运行实例）、干净卸载，并以 `--appimage-extract-and-run` 让 AppImage
  跑满 40 秒且无 `desktop policy: unsupported platform`。
- **deb 升级路径与硬化内核下的启动**（run `37095694923`）：先装 `v0.2.0-rc.2-linux.1`，再在其上
  安装 `…-linux.2`，旧的 `/usr/bin/DeepSeek Harness` 链接被清除，而 `update-alternatives`
  仍正确解析 `/usr/bin/deepseek-harness`。在 `kernel.apparmor_restrict_unprivileged_userns=1`
  （Ubuntu 23.10+ 的默认姿态，也是 AppImage 在那些系统上可能起不来的原因）下，包会安装
  `/etc/apparmor.d/deepseek-harness`，应用**不加 `--no-sandbox`** 也能启动并通过整套会话检查
  （`chrome-sandbox` 保持 0755，靠 profile 完成沙箱）。
- **Wayland**（run `37135502569`）：在 headless Weston 合成器下用 `--ozone-platform=wayland`
  启动已发布的 deb，应用以**纯 Wayland 客户端**（无 X 服务器）启动并提供本机端点，无
  `desktop policy: unsupported platform`。日志里的 DRM render-node 与 `wl_seat` 警告来自
  headless 合成器没有 GPU/输入设备，与应用无关。
- **13 个补丁的完整门禁集**（run `37411910000`，2026-10-06，head `d70585e`；其后由 push 触发的
  run `37431745619`（`main`，head `6380440`）复现了完全相同的结果）：8 个 job 里 7 个绿，
  含 `install + typecheck + package preflight`、打包、Debian 13、deb 升级路径与硬化启动、
  已发布产物校验、Wayland 冒烟。`upstream Linux gates, sandbox confinement, keyless agent smoke`
  报 **failure**，但只卡在它的 `Verdict` 汇总步 —— sandbox confinement 与 keyless agent smoke
  两条腿都过，红的是上游门禁聚合本身；而它在**同一次运行的未打补丁基线 tag** 上挂的是
  **同样两个任务、同样四个测试**：`test:coverage`（37874 个通过里，`scripts/persistence-schema.spec.ts`
  有一个 5 秒超时）与 `web browser snapshot`（`declared-reasoning.e2e.ts`、`document-preview.e2e.ts`、
  `session-replay-reload.e2e.ts`）。归因因此是确定的 —— 四个都不属于本补丁集，
  且 `patches/0013` 只碰 `apps/desktop/src/main.ts`。
  **归因已定、修复已应用：** `web browser snapshot` 那条红是因为两处 `Install Playwright browsers`
  步骤此前用的是 `playwright install chromium webkit`、**没有** `--with-deps`，跑器拿到了浏览器二进制
  却缺少 WebKit 的系统库（`libgtk-4.so.1`、`libgraphene-1.0.so.0`、`libgst*.so.0`、`libopus.so.0`、
  `libevent-2.1.so.7`）；挂掉的正是测试名里带 `('WebKit')` 的那几个。两处现已补上 `--with-deps`，
  但该腿**尚未重跑**，故上面记录的仍是本次运行的结果。注意 `--with-deps` 只解决这一腿：
  `test:coverage` 是**独立**失败的（`scripts/persistence-schema.spec.ts:508` 单个 flaky 用例），
  且在未打补丁的基线 tag 上同样失败 —— 所以在第二条腿单独处理之前，门禁聚合仍会是红。

本环境未验证：

- Electron `titleBarOverlay` 在各桌面环境下的观感；窗口拖拽/缩放与两种主题下的标题栏尺寸。
- 桌面集成本身（托盘、通知、真实会话里的窗口控件）；上面的套件覆盖的是打包后的运行时，
  不是正在运行的桌面。

## 9. 已知限制

- **无法 1:1 的部分**：macOS 红绿灯按钮、侧栏 `vibrancy` 毛玻璃、Dock 跳动。本补丁集用
  原生 overlay 窗口控件、纯色侧栏与通知替代。
- **`dsh` 命令依赖 `deb`**：AppImage 的资源在临时挂载点，从它安装命令会被拒绝并给出可操作的
  提示（解出目录树时可用 `DSH_DESKTOP_RESOURCES` 兜底）。
- **平台标识**：Linux 构建会向 DeepSeek Platform 上报 macOS 桌面标识，因为共享账号包对
  `x-client-platform` 只定义了 `darwin`/`win32`（省略会退化成 `web`）。
- **强更策略在 Linux 上不生效**（没有官方 Linux 更新源）。
- 只支持 `linux-x64`；`linux-arm64` 不在本系列内。
- 欢迎窗口的标题栏配色只在创建时跟随系统主题。
- `deb` 的 maintainer 字段是占位符（`DeepSeek Harness`）。
- **第二次"关窗→唤回"不会把窗口找回来**：关掉最后一个窗口后应用与其 Host 继续运行（这是设计），
  之后的第一次激活或启动都能把窗口找回；但**再关一次之后**，进程仍在服务却什么都不显示 ——
  `ci/desktop-session.sh` 里只剩 10x10 的托盘辅助窗口，而 Host 端点仍在应答。
  该问题在 CI run `37089025040` 中发现；曾尝试的修复未改变行为，故已撤回。
- **两项检查无法在 Debian 容器 job 里真跑**：Docker 默认 seccomp 禁止 `unshare`，因此 bwrap
  沙箱腿在那里自跳过（Landlock 腿严格跑并通过），而无 key agent 冒烟会在读取自己的会话目录时
  失败（`ENOENT …/.sessions`）且 harness 没有把驱动的 stderr 带出来，所以只做**报告**、不作为门禁。
  这两项在 Ubuntu runner 上都是严格门控的（那里的内核允许所需的 namespace）。

## 10. 目录结构、许可与署名

```
patches/0001..0013*.patch   git format-patch 序列，按文件名顺序应用
apply.sh                    克隆上游基线 tag、应用序列、生成 .env.linux
verify.sh                   一次性 Linux 诊断脚本（--env-only / --full），产出诊断 tarball
LINUX-DESKTOP.md            长文指南：逐文件说明、已验证事实、待办项
LICENSE                     MIT（上游 DeepSeek + 本补丁集）
```

`verify.sh` 是在你的 Linux 主机上构建失败时该跑的诊断脚本：逐步记录 PASS/FAIL，并产出可直接
附到 issue 里的 `dsh-verify-<时间戳>.tar.gz`。它不使用 `sudo`，只写 `verify-logs/` 下的内容。

每个补丁一个主题：(1) 接受该目标，(2) 安装 `dsh` 命令，(3) 准备 Linux 运行时 payload，
(4) macOS 风格的 shell 行为，(5) 文档，(6) 打包类型声明，(7) Debian 安全可执行名，
(8) 升级时清理旧启动器，(9) 补齐安装器配置声明里的 Linux 字段，(10) 让 Linux 启动器取到
`app.asar` 内的 `dsh` payload，(11) 保留 upload-plan 报错里的 update 环境，(12) 满足上游仓库
门禁，(13) 激活重建窗口时把它显示出来。

本补丁集以 MIT 许可分发（见 `LICENSE`）。这些补丁是针对
[deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的 diff，
上游同为 MIT，Copyright (c) 2026 DeepSeek；该声明在此保留。

与 DeepSeek 无关联、未获其背书或支持。上游处于开发者预览、迭代很快，向更新的 tag 变基时
预计会有冲突。

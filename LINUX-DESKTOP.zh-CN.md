[English](LINUX-DESKTOP.md) | 中文

# Linux 桌面构建与验收指南

## 0. 范围

本文记录 `dsh-v0.2.1-rc.5` 上的验证，固定携带 `dsh-scnet@0.6.13`；实际构建始终从 ci/upstream-base-tag 读取当前固定 tag。[README](README.zh.md)区分源码能力和已发布的 `v0.2.1-rc.5-linux.1` 预发布包。历史 0.2.0 主题补丁已归档，不得混入当前补丁线。

## 1. 构建前置

使用 Linux x86_64、Node `^22.19.0 || >=24.0.0`、pnpm `11.7.0`、Git 和至少 15 GB 空闲磁盘。上游工作区有自己的包管理器固定版本；打包命令会检查 Linux x64 主机。依赖下载需要 npm、GitHub/Electron、Node 和 Python 分发网络；不可达时应配置合适代理或获准镜像。

桌面验收需要真实 X11/Wayland 会话。Xvfb、Openbox、xdotool 和 dbus-x11 用于自动无头会话。应用通过内置 WASM LibreOffice 转换文档，该路径不要求系统 LibreOffice。

## 2. 准备上游源码

使用 [README](README.zh.md) 中的命令。`apply.sh` 从 [ci/upstream-base-tag](ci/upstream-base-tag) 读取基线，`BASE_TAG` 可覆盖；通过 `git apply --3way` 应用 `patches/*.patch`，改动留在暂存区，并从模板生成 `apps/desktop/.env.linux`。必须使用新 checkout；重复应用已打过的补丁不是更新操作。

`git rev-parse HEAD` 标识未打补丁的基线，暂存区补丁树用 `git write-tree`；未暂存的修改不会计入。请审查 `git diff --cached`，不要期待每个补丁都有提交或 status 为空。`.env.linux` 保持本地，只使用当前模板允许的设置。

`ci/update-upstream-and-build.sh` 用于本地迁移；每日同步 workflow 验证较新的后继 tag 并创建 PR，alpha 迁移需要显式选择。详见[同步操作](ci/UPSTREAM-SYNC.zh-CN.md)。

## 3. 构建、审计和安装

安装依赖、类型检查、host/desktop 构建后，运行 `check:package`，再运行 `package:linux:x64`。可用 `package:linux:x64:dir` 生成未打包目录辅助调试，但它不能证明 deb 安装可用。

```sh
export TARGET_DIR="$SRC/apps/desktop/.desktop-build/targets/linux-x64"
export ARTIFACTS="$TARGET_DIR/artifacts"
git -C "$SRC" diff --cached --stat
git -C "$SRC" write-tree
ls -lh "$ARTIFACTS"/*.deb
node "$PATCH_REPO/ci/scnet-release-audit.mjs" \
  --deb "$(find "$ARTIFACTS" -maxdepth 1 -name '*.deb' -print -quit)" \
  --package-set "$TARGET_DIR/package-set" --expected-version 0.6.13 --require-setup true
sudo apt-get install --reinstall "$ARTIFACTS"/deepseek-harness-*-linux-amd64.deb
deepseek-harness
```

审计使用产物自带的 Electron 读取精确归档，检查 Bundle/Skill 固定版本、package-set 完整性与许可证、runtime descriptor 哈希、凭据/私网 endpoint 和生成缓存。`--require-setup true` 额外要求物理解包后的 SCNet 文件与归档一致，并由外部 Python 执行打包向导的帮助命令；只有审计早于此修复的历史包时才省略该选项。

产物位于 `$TARGET_DIR`：`artifacts/` 放 deb/未打包应用，`runtime/` 放准备好的运行时，`dsh/` 放生产依赖树，`package-set/` 和 `downloads/` 放中间输入，`packaging-runs/` 放构建记录。安装后的启动器是 `/usr/bin/deepseek-harness`，目标为 `/opt/DeepSeek Harness/deepseek-harness`。生产 CLI payload 位于 `resources/app.asar/dsh`，普通 shell 文件检查不能读取虚拟归档路径；外部 Python 必须使用 `app.asar.unpacked`。

## 4. 验收清单

| 能力 | 验收 |
| --- | --- |
| 启动与窗口 | 显示工作区/欢迎页，无平台拒绝；检查拖拽/缩放、深浅主题和原生边框兜底 |
| 后台任务 | 关掉最后一个窗口后 Host/任务继续运行；托盘或“显示窗口”能恢复窗口 |
| 单实例 | 普通二次启动和 `dsh://open` 都能恢复窗口，不产生第二个 Host |
| CLI | 在 PATH 安装 `dsh`；外来启动器须报告/备份；deb 安装后执行成功 |
| Office | 通过内置 WASM 引擎转换代表性 DOCX/XLSX/PPTX |
| 更新 | 从设置页和应用菜单检查，取消安全；验证下载、PolicyKit 拒绝/失败、运行任务确认和重启 |
| SCNet | Bundle/Skill 离线可用，默认/禁用/自定义 profile 保留，诊断不暴露凭据 |
| 开发者工具 | 中英文菜单和 F12/原生快捷键作用于预期产品文档 |
| 故障恢复 | 区分报告已保存、慢保存和失败；获取报告不重启应用 |
| 更新视图 | 标题栏/全屏尺寸正确、不在后台激活，关闭后恢复输入，强更失败有安全兜底 |
| 配置 SCNet | 外部 Python 打开解包后的向导，失败保持可见，取消/关闭不代表登录成功 |

在补丁后的上游根目录运行定向回归：

```sh
pnpm exec vitest run apps/desktop/tests/fatal-recovery.spec.ts \
  apps/desktop/tests/update-overlay.spec.ts apps/desktop/tests/update-dialog.spec.ts \
  apps/desktop/tests/mandatory-update-window.spec.ts apps/desktop/tests/main-startup.spec.ts \
  apps/desktop/tests/keyboard.spec.ts apps/desktop/tests/harness-update.spec.ts \
  apps/desktop/tests/scnet-diagnostics-window.spec.ts apps/desktop/tests/scnet-setup.spec.ts \
  apps/desktop/tests/installer-packaging.spec.ts
```

Ubuntu CI 通过 `ci/desktop-session.sh` 安装并启动构建的 deb，覆盖映射窗口、关窗保活、profile 激活和深链路由。Xvfb 明确跳过普通二次启动断言；真实桌面、Wayland、keyring 和用户交互验收仍需独立证据。

## 5. 已知限制

只维护 Linux x64 deb。ARM64、AppImage 和 RPM 需要单独的打包/运行时验证。macOS 红绿灯、vibrancy 和 Dock 提醒不属于 Linux 功能；Linux 使用 overlay 标题栏或 `DSH_DESKTOP_LINUX_NATIVE_FRAME=1`，以及桌面自身的托盘/通知。

没有官方 Linux 更新源。本移植通过 Linux release 包和系统安装器一起交付客户端与 Harness。从 `v0.2.1-rc.5-linux.2` 起，每个 release 都会为 `SHA256SUMS` 发布 Ed25519 分离签名；应用只安装清单能通过内置公钥（同时提交在 `ci/release-signing-key.pub.pem`）校验的更新。同一 release 里的 `desktop-policy.json` 声明最低支持版本和构建号，较旧客户端会看到“必须更新”而不是普通更新。该策略文件不能授权未签名包；它被签名清单覆盖，只在检查时读取。SCNet 本地就绪不代表 OAuth2 登录或 SSH 访问，两者有不同前置。共享账户协议当前只接受 macOS/Windows 桌面平台值，因此 Linux 使用上游桌面标识兜底。

CUA 需要 Linux 原生权限/控制实现，新文件交互和完整插件历史需要新版共享 API，见[功能跟进](docs/DESKTOP-FOLLOWUP.zh-CN.md)。历史测试数量和平台运行不能证明当前 release 正确。

## 6. 排障

| 症状 | 检查 |
| --- | --- |
| 不支持 linux-x64 或补丁冲突 | 全新固定基线、只用当前补丁线、完整补丁日志 |
| 缺少 .env.linux | 复制当前模板，核对允许设置和 app ID |
| 主机/工具链不符 | Linux x86_64、受支持 Node 和实际选择的 pnpm |
| 依赖/Electron 下载超时 | 代理、registry 和 Electron 镜像，不通过改补丁掩盖网络失败 |
| Office WASM 缺失 | 生产运行时闭包和 package-set 清单 |
| 深链无效 | `xdg-mime query default x-scheme-handler/dsh` 应返回 `deepseek-harness.desktop` |
| SCNet 配置不可用 | 物理解包脚本、可执行的配置 Python、受支持终端和可见终端输出 |
| Sandbox 拒绝 | 检查 user namespace、AppArmor、SUID helper 配置；正常桌面运行保留 sandbox |

`verify.sh` 逐步记录 PASS/FAIL 并生成诊断 tarball，不使用 sudo，也不能替代安装后的桌面验收。完整模式的 SCNet 审计使用当前固定版本，并验收物理解包后的配置文件。

## 7. 验证边界

[Linux 验证流程](.github/workflows/linux-desktop-verify.yml)才是具体提交的依据。PR/main 检查源码、回归、候选包和 Ubuntu 无头安装；手动 job 检查长期上游门禁、真实内核 bwrap/Landlock 和 keyless smoke、发布字节、AppArmor、Wayland、Debian 13 和 profile 升级。

上游门禁只容忍精确列举的三项 coverage 竞态，其余失败仍为失败，不是通用 coverage 豁免。截图或无头启动不能证明真实桌面焦点、文件拖放、keyring 生命周期或所有合成器组合。手动结果必须记录包 checksum、源码提交、run、桌面/合成器和实际执行行为。

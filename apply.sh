#!/usr/bin/env sh
# 在 Linux 上把本补丁集应用到上游 deepseek-harness 的一个新分支，并准备好打包所需的本地环境文件。
#
# 用法：
#   ./apply.sh                       # 当前目录下创建 ./deepseek-harness
#   ./apply.sh /path/to/deepseek-harness
#   ./apply.sh --install [路径]      # 打完补丁后顺带执行 pnpm install --frozen-lockfile
#
# 注意：本脚本只负责"拿到能构建的源码树"。真正的构建/打包命令在结尾打印。
set -eu

PATCH_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/patches" && pwd -P)
BASE_TAG=${BASE_TAG:-dsh-v0.2.0-rc.2}
BRANCH=${BRANCH:-linux-desktop}
UPSTREAM=${UPSTREAM:-https://github.com/deepseek-ai/deepseek-harness.git}

INSTALL=0
if [ "${1:-}" = "--install" ]; then INSTALL=1; shift; fi
DEST=${1:-deepseek-harness}

need() { command -v "$1" >/dev/null 2>&1; }
warn() { echo "警告：$*" >&2; }

# --- 前置检查（只警告，不拦你）------------------------------------------------
need git || { echo "错误：缺少 git。" >&2; exit 1; }

if need node; then
  node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit((a===22&&b>=19)||a>=24?0:1)' \
    || warn "Node $(node -v) 不在 ^22.19 || >=24 范围内，构建可能失败。"
else
  warn "未找到 node。构建需要 Node ^22.19 || >=24 与 pnpm 11.7.0。"
fi

if need pnpm; then
  warn_pnpm=$(pnpm --version 2>/dev/null || echo unknown)
  [ "$warn_pnpm" = "11.7.0" ] || warn "pnpm 版本是 ${warn_pnpm}，仓库声明的是 11.7.0（建议 corepack enable）。"
else
  warn "未找到 pnpm。建议 corepack enable，或 npm i -g pnpm@11.7.0。"
fi

# --- 克隆并切到工作分支 -------------------------------------------------------
if [ ! -d "$DEST/.git" ]; then
  echo "==> 克隆 ${UPSTREAM}（tag ${BASE_TAG}，浅克隆）到 $DEST"
  git clone --branch "$BASE_TAG" --depth 1 "$UPSTREAM" "$DEST"
fi

cd "$DEST"
if [ "$(git rev-parse --abbrev-ref HEAD)" != "$BRANCH" ]; then
  git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
fi
echo "==> 工作分支 ${BRANCH}，HEAD $(git rev-parse --short HEAD)"

# --- 打补丁（git am 需要提交身份；缺失时用一次性身份，不动你的全局配置）------
AM='git am'
if [ -z "$(git config user.email || true)" ] || [ -z "$(git config user.name || true)" ]; then
  echo "==> 检测到未配置 git 提交身份，本次 git am 使用一次性身份（不写入你的 git 配置）"
  AM='git -c user.name=linux-port -c user.email=linux-port@localhost am'
fi

echo "==> 应用补丁：$(ls -1 "$PATCH_DIR"/*.patch | wc -l | tr -d ' ') 个"
# shellcheck disable=SC2086 # $AM 需要按空格拆成"git -c … am"
$AM "$PATCH_DIR"/*.patch

# --- 生成打包必需的本地环境文件 ----------------------------------------------
# loadDesktopPackageEnvironment() 读不到 apps/desktop/.env.linux 会直接报错，
# 所以打完补丁必须有一份（模板里除 APP_ID 外全部可选）。
if [ ! -f apps/desktop/.env.linux ]; then
  cp apps/desktop/.env.linux.example apps/desktop/.env.linux
  echo "==> 已按模板生成 apps/desktop/.env.linux（需要自定义 APP_ID / 更新源时再改）"
fi

if [ "$INSTALL" = "1" ]; then
  if need pnpm; then
    echo "==> pnpm install --frozen-lockfile"
    pnpm install --frozen-lockfile
  else
    warn "跳过 pnpm install：未找到 pnpm。"
  fi
fi

cat <<'EOF'

==> 源码已就绪。接下来（在 Linux 上）：

    cd <这个目录>
    pnpm install --frozen-lockfile                    # 若用了 --install 则已完成
    pnpm --dir apps/desktop run package:linux:x64:dir # 先出目录产物，验证能否启动
    pnpm --dir apps/desktop run package:linux:x64     # 再出 deb

验收清单见 LINUX-DESKTOP.md 第 4 节；已知限制见第 5 节；
必须在 Linux 现场确认的项见第 7 节（第一次真类型检查、DE 下的窗口控件、CLI/深链、Office WASM 引擎）。
EOF

#!/usr/bin/env bash
# Migrate the Linux patch series onto the newest non-alpha upstream Harness tag and build a Linux deb.
#
# Usage:
#   ./ci/update-upstream-and-build.sh
#   ./ci/update-upstream-and-build.sh --tag dsh-v0.2.1-rc.2
#   ./ci/update-upstream-and-build.sh --install --build-version 0.2.1-rc.2-linux.1
#
# A patch conflict is left in the temporary checkout so it can be inspected and
# resolved manually; the script never reports a conflicted migration as success.
set -Eeuo pipefail

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
UPSTREAM_REPO=${DSH_UPSTREAM_REPOSITORY:-https://github.com/deepseek-ai/deepseek-harness.git}
BASE_TAG=${DSH_BASE_TAG:-$(cat "$REPO_ROOT/ci/upstream-base-tag")}
REQUESTED_TAG=''
BUILD_VERSION=''
INSTALL=0
KEEP=0

usage() {
  cat <<'EOF'
Usage: ci/update-upstream-and-build.sh [options]

Options:
  --tag TAG             Migrate onto an exact upstream tag.
  --build-version VER   Override the Linux package version passed to the builder.
  --install             Install the built deb with apt after all checks pass.
  --keep                Keep the migrated checkout and build artifacts.
  -h, --help            Show this help.

Environment:
  DSH_UPSTREAM_REPOSITORY
                        Upstream repository URL.
                        Default: https://github.com/deepseek-ai/deepseek-harness.git
  DSH_BASE_TAG         Existing patch-series base tag used for three-way migration.
                        Default: contents of ci/upstream-base-tag
  DSH_UPSTREAM_DIR      Optional checkout path. Without it a temporary directory is used.
EOF
}

while (($# > 0)); do
  case "$1" in
    --tag)
      (($# >= 2)) || { echo "error: --tag requires a value" >&2; exit 2; }
      REQUESTED_TAG=$2
      shift 2
      ;;
    --build-version)
      (($# >= 2)) || { echo "error: --build-version requires a value" >&2; exit 2; }
      BUILD_VERSION=$2
      shift 2
      ;;
    --install)
      INSTALL=1
      shift
      ;;
    --keep)
      KEEP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

for command in git pnpm node sha256sum dpkg-deb; do
  require_command "$command"
done
if ((INSTALL)); then
  require_command sudo
  require_command apt-get
fi

patch_count=$(find "$REPO_ROOT/patches" -maxdepth 1 -type f -name '*.patch' | wc -l | tr -d ' ')
(( patch_count > 0 )) || {
  echo "error: no patch files found under $REPO_ROOT/patches" >&2
  exit 1
}

if [[ -n "$REQUESTED_TAG" ]]; then
  UPSTREAM_TAG=$REQUESTED_TAG
else
  echo "==> Resolving the newest upstream dsh-v* tag (automatic selection excludes alpha tags)"
  UPSTREAM_TAG=$(git ls-remote --tags --refs "$UPSTREAM_REPO" 'dsh-v*' \
    | awk '$2 !~ /-alpha([.-]|$)/ {sub("refs/tags/", "", $2); print $2}' \
    | sort -V | tail -n1)
fi
[[ "$UPSTREAM_TAG" == dsh-v* ]] || {
  echo "error: could not resolve an upstream dsh-v* tag" >&2
  exit 1
}

if [[ -n "${DSH_UPSTREAM_DIR:-}" ]]; then
  BUILD_ROOT=$DSH_UPSTREAM_DIR
  if [[ -e "$BUILD_ROOT" ]]; then
    echo "error: DSH_UPSTREAM_DIR already exists: $BUILD_ROOT" >&2
    echo "       choose another path or remove it after reviewing its contents" >&2
    exit 1
  fi
  CLEANUP_ROOT=0
else
  BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/deepseek-harness-upstream.XXXXXX")
  CLEANUP_ROOT=1
fi

SUCCESS=0
cleanup() {
  if ((SUCCESS)) && ((CLEANUP_ROOT)) && ((!KEEP)); then
    rm -rf -- "$BUILD_ROOT"
  else
    echo "==> Migrated checkout retained at: $BUILD_ROOT"
  fi
}
trap cleanup EXIT

echo "==> Upstream tag: $UPSTREAM_TAG"
echo "==> Patch base: $BASE_TAG"
echo "==> Patch series: $patch_count patches"
echo "==> Checkout: $BUILD_ROOT"
git clone --no-checkout "$UPSTREAM_REPO" "$BUILD_ROOT"
git -C "$BUILD_ROOT" fetch --quiet origin \
  "refs/tags/$BASE_TAG:refs/tags/$BASE_TAG" \
  "refs/tags/$UPSTREAM_TAG:refs/tags/$UPSTREAM_TAG"
git -C "$BUILD_ROOT" checkout -b "linux-desktop-${UPSTREAM_TAG#dsh-}" "$UPSTREAM_TAG"

echo "==> Applying the Linux port diff with git apply --3way"
if ! git -C "$BUILD_ROOT" apply --3way "$REPO_ROOT"/patches/*.patch; then
  echo >&2
  echo "Migration stopped on a patch conflict." >&2
  echo "Resolve it in the retained checkout, then run:" >&2
  echo "  git -C '$BUILD_ROOT' status" >&2
  echo "  git -C '$BUILD_ROOT' add <resolved-files>" >&2
  exit 1
fi
if [[ -n "$(git -C "$BUILD_ROOT" diff --name-only --diff-filter=U)" ]]; then
  echo "error: unresolved files remain after applying the Linux port diff" >&2
  git -C "$BUILD_ROOT" status --short >&2
  exit 1
fi

if [[ ! -f "$BUILD_ROOT/apps/desktop/.env.linux" ]]; then
  cp "$BUILD_ROOT/apps/desktop/.env.linux.example" "$BUILD_ROOT/apps/desktop/.env.linux"
fi

echo "==> Installing dependencies"
( cd "$BUILD_ROOT" && pnpm install --frozen-lockfile )

echo "==> Running repository typecheck"
( cd "$BUILD_ROOT" && pnpm run typecheck )

echo "==> Building host libraries required by the Desktop bundle"
( cd "$BUILD_ROOT" && pnpm run build:lib:host )

echo "==> Running Linux package preflight"
( cd "$BUILD_ROOT" && pnpm --dir apps/desktop run check:package )

echo "==> Building the Linux deb"
build_args=(pnpm --dir apps/desktop run package:linux:x64)
if [[ -n "$BUILD_VERSION" ]]; then
  build_args+=(-- --build-version "$BUILD_VERSION")
fi
(
  cd "$BUILD_ROOT"
  DSH_DESKTOP_TARGET_PLATFORM=linux \
  DSH_DESKTOP_TARGET_ARCH=x64 \
  "${build_args[@]}"
)

artifact_dir="$BUILD_ROOT/apps/desktop/.desktop-build/targets/linux-x64/artifacts"
mapfile -t debs < <(find "$artifact_dir" -maxdepth 1 -type f -name '*.deb' -print | sort)
(( ${#debs[@]} == 1 )) || {
  echo "error: expected exactly one Linux deb, found ${#debs[@]}" >&2
  exit 1
}
deb=${debs[0]}
printf '==> Built: %s\n' "$deb"
printf '==> Architecture: %s\n' "$(dpkg-deb --field "$deb" Architecture)"
printf '==> Package version: %s\n' "$(dpkg-deb --field "$deb" Version)"
sha256sum "$deb"

if ((INSTALL)); then
  echo "==> Installing the migrated build"
  sudo apt-get install --reinstall "$deb"
  dpkg-query -W -f='${binary:Package}\t${Version}\n' deepseek-harness
fi

SUCCESS=1
if ((KEEP)); then
  echo "==> Keeping checkout and artifacts: $BUILD_ROOT"
fi
echo "==> Upstream migration and Linux build completed successfully."


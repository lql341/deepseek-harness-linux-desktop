#!/usr/bin/env bash
# One-shot diagnostic for the Linux desktop patch set.
#
# Run this on the machine where the build fails (Ubuntu/Debian, x86_64) and send
# back the tarball it prints at the end. Every step records PASS/FAIL so a partial
# run is still useful.
#
#   ./verify.sh              environment report + install + typecheck   (fast path)
#   ./verify.sh --full       everything, including packaging and smokes
#   ./verify.sh --env-only   environment report only
#
# It never uses sudo and never modifies anything outside its working directory.

set -uo pipefail

MODE=quick
case "${1:-}" in
  --full) MODE=full ;;
  --env-only) MODE=env ;;
  -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
  '') ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
UPSTREAM_DIR=${UPSTREAM_DIR:-"$REPO_ROOT/../deepseek-harness"}
STAMP=$(date +%Y%m%d-%H%M%S)
LOGROOT="$REPO_ROOT/verify-logs/$STAMP"
mkdir -p "$LOGROOT"

step()  { printf '\n=== %s ===\n' "$*" | tee -a "$LOGROOT/summary.txt"; }
pass()  { printf 'PASS: %s\n' "$*" | tee -a "$LOGROOT/summary.txt"; }
fail()  { printf 'FAIL: %s\n' "$*" | tee -a "$LOGROOT/summary.txt"; }
note()  { printf 'note: %s\n' "$*" | tee -a "$LOGROOT/summary.txt"; }
run()   { local name=$1; shift; "$@" >"$LOGROOT/$name.log" 2>&1; local rc=$?;
          if [ $rc -eq 0 ]; then pass "$name"; else fail "$name (exit $rc, see $name.log)"; fi; return $rc; }

# ---------------------------------------------------------------- L0: environment
step "L0 environment"
{
  echo "date: $(date)"
  echo "uname: $(uname -a)"
  echo "distro:"; cat /etc/os-release 2>/dev/null | head -5
  echo "glibc: $(ldd --version 2>/dev/null | head -1)"
  echo "arch: $(uname -m)"
  echo "cpu: $(nproc 2>/dev/null || echo '?')   mem: $(free -h 2>/dev/null | awk '/Mem:/{print $2}')"
  echo "disk (home):"; df -h "$HOME" 2>/dev/null | tail -1
  echo "node: $(command -v node >/dev/null && node -v || echo 'missing')"
  echo "pnpm: $(command -v pnpm >/dev/null && pnpm -v || echo 'missing')"
  echo "git: $(git --version 2>/dev/null || echo missing)"
  echo "xvfb-run: $(command -v xvfb-run || echo missing)"
  echo "bubblewrap: $(command -v bwrap || echo missing)"
  echo "kernel: $(uname -r)   landlock: $(grep -c landlock /proc/kallsyms 2>/dev/null || echo '?')"
} >"$LOGROOT/00-environment.log" 2>&1
cat "$LOGROOT/00-environment.log" | tee -a "$LOGROOT/summary.txt"

if [ "$MODE" != env ]; then
  step "L0 network reachability (build needs these)"
  {
    for url in https://registry.npmjs.org/ https://registry.npmmirror.com/ https://nodejs.org/ https://github.com/ https://pypi.org/; do
      code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$url" 2>/dev/null || echo "ERR")
      printf '%-38s %s\n' "$url" "$code"
    done
  } >"$LOGROOT/01-network.log" 2>&1
  cat "$LOGROOT/01-network.log" | tee -a "$LOGROOT/summary.txt"
  grep -qE ' (200|30[0-9])$' "$LOGROOT/01-network.log" && pass "network: at least one endpoint reachable" \
    || fail "network: no endpoint reachable (build cannot proceed)"
fi

if [ "$MODE" = env ]; then
  echo; echo "tarball:"; tar -czf "$REPO_ROOT/dsh-verify-$STAMP.tar.gz" -C "$(dirname "$LOGROOT")" "$STAMP" && echo "$REPO_ROOT/dsh-verify-$STAMP.tar.gz"
  exit 0
fi

# ------------------------------------------------- L1: patch + install + typecheck
step "L1 apply patch series"
if [ -d "$UPSTREAM_DIR/.git" ]; then
  note "upstream checkout already exists: $UPSTREAM_DIR"
  run "10-upstream-head" git -C "$UPSTREAM_DIR" log --oneline -3
else
  run "10-apply" "$REPO_ROOT/apply.sh" "$UPSTREAM_DIR"
fi
if [ -f "$UPSTREAM_DIR/apps/desktop/.env.linux" ]; then pass "apps/desktop/.env.linux present"
else
  cp "$UPSTREAM_DIR/apps/desktop/.env.linux.example" "$UPSTREAM_DIR/apps/desktop/.env.linux" \
    && pass "created apps/desktop/.env.linux from the template" || fail "cannot create .env.linux"
fi
run "11-patched-tree" bash -c "cd '$UPSTREAM_DIR' && git rev-parse 'HEAD^{tree}'"

step "L1 install"
( cd "$UPSTREAM_DIR" && pnpm install --frozen-lockfile ) >"$LOGROOT/20-install.log" 2>&1
if [ $? -eq 0 ]; then pass "pnpm install"; else fail "pnpm install (see 20-install.log)"; fi

step "L1 typecheck"
( cd "$UPSTREAM_DIR" && pnpm run typecheck ) >"$LOGROOT/21-typecheck.log" 2>&1
if [ $? -eq 0 ]; then pass "repo typecheck"; else fail "repo typecheck (see 21-typecheck.log)"; fi

( cd "$UPSTREAM_DIR" && pnpm --dir apps/desktop run build ) >"$LOGROOT/22-desktop-build.log" 2>&1
if [ $? -eq 0 ]; then pass "desktop build"; else fail "desktop build (see 22-desktop-build.log)"; fi

step "L1 packaging preflight"
( cd "$UPSTREAM_DIR" && pnpm --dir apps/desktop run check:package ) >"$LOGROOT/23-check-package.log" 2>&1
if [ $? -eq 0 ]; then pass "check:package"; else fail "check:package (see 23-check-package.log)"; fi

if [ "$MODE" != full ]; then
  step "done (quick mode)"
  note "run '$0 --full' on this machine for packaging and runtime smokes"
else
  # ------------------------------------------------------------- L2/L3/L4
  step "L2 package --dir"
  ( cd "$UPSTREAM_DIR" && pnpm --dir apps/desktop run package:linux:x64:dir ) >"$LOGROOT/30-package-dir.log" 2>&1
  if [ $? -eq 0 ]; then pass "package:linux:x64:dir"; else fail "package:linux:x64:dir (see 30-package-dir.log)"; fi

  ART="$UPSTREAM_DIR/apps/desktop/.desktop-build/targets/linux-x64/artifacts"
  APP="$ART/linux-unpacked"
  step "L2 artifact inspection"
  {
    ls -la "$ART" 2>/dev/null
    echo; echo "-- launcher --"; ls -l "$APP/DeepSeek Harness" 2>/dev/null || echo "launcher missing"
    echo; echo "-- asar --"; ls -l "$APP/resources/app.asar" 2>/dev/null || echo "app.asar missing"
    echo; echo "-- linux native packages --"
    for p in node-pty sharp-linux koffi-linux ripgrep-linux node-addon-system-linux sherpa-onnx-linux libreoffice-kit-wasm; do
      printf '%-32s' "$p"
      find "$APP/resources" -maxdepth 6 -name "*${p}*" -print -quit 2>/dev/null | grep -q . && echo present || echo MISSING
    done
    echo; echo "-- darwin/windows leftovers --"
    find "$APP/resources" -maxdepth 6 \( -name '*-darwin-*' -o -name '*-win32-*' -o -name '*.dll' \) 2>/dev/null | head -20
  } >"$LOGROOT/31-inspection.log" 2>&1
  cat "$LOGROOT/31-inspection.log" | tee -a "$LOGROOT/summary.txt"
  grep -q "MISSING" "$LOGROOT/31-inspection.log" && fail "some expected Linux packages are missing" || pass "artifact contents look complete"

  step "L3 headless runtime smoke"
  BIN="$APP/DeepSeek Harness"; [ -x "$BIN" ] || BIN="$APP/deepseek-harness"
  HOSTCLI="$APP/resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js"
  if [ -x "$BIN" ] && [ -f "$HOSTCLI" ]; then
    ELECTRON_RUN_AS_NODE=1 "$BIN" --expose-internals "$HOSTCLI" --version >"$LOGROOT/32-runtime-smoke.log" 2>&1
    if [ $? -eq 0 ]; then pass "bundled runtime responds"; else fail "bundled runtime smoke (see 32-runtime-smoke.log)"; fi
    cat "$LOGROOT/32-runtime-smoke.log" | tee -a "$LOGROOT/summary.txt"
  else
    fail "runtime smoke skipped (launcher or bundled host cli missing)"
  fi

  step "L4 GUI smoke under Xvfb (best effort)"
  if command -v xvfb-run >/dev/null 2>&1 && [ -x "$BIN" ]; then
    timeout 40 xvfb-run -a "$BIN" --no-sandbox --enable-logging >"$LOGROOT/33-gui-smoke.log" 2>&1
    note "GUI smoke finished; inspect 33-gui-smoke.log for 'unsupported platform' or window errors"
  else
    note "xvfb-run missing or no launcher: install xvfb (needs sudo) to cover this layer"
  fi
fi

cd "$(dirname "$LOGROOT")"
tar -czf "$REPO_ROOT/dsh-verify-$STAMP.tar.gz" "$STAMP"
echo
echo "================================================================"
echo "send this file back: $REPO_ROOT/dsh-verify-$STAMP.tar.gz"
echo "it contains the environment report, per-step logs and summary.txt"
echo "================================================================"

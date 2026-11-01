#!/usr/bin/env bash
# Collect real-desktop acceptance evidence for an installed Linux package.
#
# Run this on the machine that has the desktop session under test, as the user who
# uses it, with the application installed. It records the session/compositor, the
# package and desktop-integration facts, capability probes, an automated
# window/close/deep-link pass, and an interactive checklist. The evidence lands in
# one directory plus a tarball that can be attached to an issue.
#
#   bash ci/real-desktop-acceptance.sh
#   bash ci/real-desktop-acceptance.sh --non-interactive --skip-session --report-dir /tmp/report
#
# Quit the application before running: the automated pass starts its own instance
# and Electron's single-instance lock would otherwise route to yours.
#
# It changes nothing outside the report directory and never uses sudo.

set -uo pipefail

NON_INTERACTIVE=0
SKIP_SESSION=0
STRICT=0
REPORT_DIR=
while [ $# -gt 0 ]; do
  case "$1" in
    --non-interactive) NON_INTERACTIVE=1 ;;
    --skip-session) SKIP_SESSION=1 ;;
    --strict) STRICT=1 ;;
    --report-dir) shift; REPORT_DIR=${1:-} ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
REPORT_DIR=${REPORT_DIR:-"$REPO_ROOT/real-desktop-acceptance/$STAMP"}
mkdir -p "$REPORT_DIR"
SUMMARY="$REPORT_DIR/summary.txt"
REPORT="$REPORT_DIR/report.md"
APP_BIN=${APP_BIN:-/usr/bin/deepseek-harness}
FAILED=0
SKIPPED=0

step() { printf '\n=== %s ===\n' "$*" | tee -a "$SUMMARY"; }
pass() { printf 'PASS: %s\n' "$*" | tee -a "$SUMMARY"; }
fail() { printf 'FAIL: %s\n' "$*" | tee -a "$SUMMARY"; FAILED=$((FAILED + 1)); }
skip() { printf 'SKIP: %s\n' "$*" | tee -a "$SUMMARY"; SKIPPED=$((SKIPPED + 1)); }
note() { printf 'note: %s\n' "$*" | tee -a "$SUMMARY"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------ environment
step "session and distribution"
{
  echo "date: $(date -u)"
  echo "kernel: $(uname -srm)"
  echo "distribution:"; sed -n '1,6p' /etc/os-release 2>/dev/null | sed 's/^/  /'
  echo "session type: ${XDG_SESSION_TYPE:-unknown}"
  echo "desktop: ${XDG_CURRENT_DESKTOP:-unknown} / ${DESKTOP_SESSION:-unknown}"
  echo "display: DISPLAY=${DISPLAY:-<unset>} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<unset>}"
  echo "runtime dir: ${XDG_RUNTIME_DIR:-<unset>}"
  echo "compositor processes:"
  ps -eo comm= 2>/dev/null | grep -Ei 'gnome-shell|kwin|mutter|sway|hyprland|weston|xfwm|openbox|fluxbox|i3' \
    | sort -u | sed 's/^/  /' || true
  if have wmctrl; then echo "window manager: $(wmctrl -m 2>/dev/null | head -2 | tr '\n' ' ')"; fi
  echo "scale: ${GDK_SCALE:-1} (GDK_SCALE) / ${QT_SCALE_FACTOR:-1} (QT_SCALE_FACTOR)"
  echo "monitors: $(have xrandr && xrandr --listmonitors 2>/dev/null | tail -n +2 | wc -l || echo '?')"
} > "$REPORT_DIR/environment.txt" 2>&1
cat "$REPORT_DIR/environment.txt" | tee -a "$SUMMARY"

# ---------------------------------------------------------------------- package
step "installed package and desktop integration"
{
  if dpkg-query -W -f='${Version}\n' deepseek-harness >/dev/null 2>&1; then
    echo "version: $(dpkg-query -W -f='${Version}' deepseek-harness)"
    pass "package installed"
  else
    fail "package deepseek-harness is not installed"
  fi
  if [ -x "$APP_BIN" ]; then
    pass "launcher $APP_BIN"
    echo "launcher target: $(readlink -f "$APP_BIN")"
  else
    fail "launcher $APP_BIN is missing or not executable"
  fi
  if [ -f /usr/share/applications/deepseek-harness.desktop ]; then
    pass "desktop entry installed"
    grep -E '^(Exec|MimeType|StartupWMClass)=' /usr/share/applications/deepseek-harness.desktop
  else
    fail "desktop entry missing"
  fi
  mime_handler=$(xdg-mime query default x-scheme-handler/dsh 2>/dev/null || true)
  if [ "$mime_handler" = "deepseek-harness.desktop" ]; then
    pass "dsh:// handler is deepseek-harness.desktop"
  else
    fail "dsh:// handler is '${mime_handler:-<none>}'"
  fi
  if [ -x "$HOME/.local/bin/dsh" ]; then
    pass "CLI installed at ~/.local/bin/dsh"
  else
    skip "CLI not installed (Install it from the application menu: Manage dsh Command)"
  fi
} > "$REPORT_DIR/package.txt" 2>&1
cat "$REPORT_DIR/package.txt" | tee -a "$SUMMARY"

# ------------------------------------------------------------------ capabilities
step "desktop capabilities"
{
  if have notify-send; then pass "notify-send present"; else skip "notify-send missing (notifications may still work)"; fi
  if have gdbus; then
    owner=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.NameHasOwner org.kde.StatusNotifierWatcher 2>/dev/null || true)
    case "$owner" in
      *true*) pass "StatusNotifierWatcher present (tray)";;
      *) skip "no StatusNotifierWatcher; the tray may be hidden in this desktop";;
    esac
    secrets=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.NameHasOwner org.freedesktop.secrets 2>/dev/null || true)
    case "$secrets" in
      *true*) pass "Secret Service present";;
      *) skip "no Secret Service; SCNet token storage falls back to a local file";;
    esac
    portal=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.NameHasOwner org.freedesktop.portal.Desktop 2>/dev/null || true)
    case "$portal" in
      *true*) pass "xdg-desktop-portal present";;
      *) skip "xdg-desktop-portal absent (screen capture and file dialogs may differ)";;
    esac
  else
    skip "gdbus missing; capability probes skipped"
  fi
  if have pactl && pactl info >/dev/null 2>&1; then pass "PulseAudio/PipeWire server reachable"
  elif have pw-cli && pw-cli info 0 >/dev/null 2>&1; then pass "PipeWire reachable"
  else skip "no reachable audio server (microphone cannot be exercised)"; fi
} > "$REPORT_DIR/capabilities.txt" 2>&1
cat "$REPORT_DIR/capabilities.txt" | tee -a "$SUMMARY"

# --------------------------------------------------------------- automated pass
if [ "$SKIP_SESSION" -eq 1 ]; then
  skip "automated window/close/deep-link pass (--skip-session)"
else
  if pgrep -f '/opt/DeepSeek Harness/deepseek-harness' >/dev/null 2>&1; then
    skip "automated pass: quit the running application first (single-instance lock)"
  elif [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    skip "automated pass: no display in this shell (run it from the desktop session)"
  else
    step "automated window/close/deep-link pass"
    mkdir -p "$REPORT_DIR/session"
    if SHOT_DIR="$REPORT_DIR/session" timeout 300 bash "$REPO_ROOT/ci/desktop-session.sh" \
        > "$REPORT_DIR/session/desktop-session.log" 2>&1; then
      pass "desktop-session.sh"
    else
      fail "desktop-session.sh (see session/desktop-session.log)"
    fi
    tail -20 "$REPORT_DIR/session/desktop-session.log" | tee -a "$SUMMARY"
  fi
fi

# --------------------------------------------------------------- manual checklist
CHECKLIST=(
  "Window focus and typing: click the window, type in the composer, text appears"
  "Caption: drag by the title area, double-click to maximize, resize from an edge"
  "Tray/launcher: the icon is visible and its menu shows Open and Quit"
  "Close keeps running: close the window, tasks continue, tray or launcher restores it"
  "Deep link: 'xdg-open dsh://open' brings the window back"
  "Updates: Settings shows the installed version and Check reports current or an update"
  "Update dialog: the install confirmation is inside the window and Escape does not install"
  "SCNet: Configure SCNet opens a terminal wizard; closing it does not claim authorization"
  "Notifications: a notification appears in the desktop's notification area"
  "HiDPI/multi-monitor: text is not clipped and moving between monitors keeps the caption usable"
)
declare -a ANSWERS=()
if [ "$NON_INTERACTIVE" -eq 1 ]; then
  skip "interactive checklist (--non-interactive)"
else
  step "interactive checklist (y = pass, n = fail, s = skip)"
  for item in "${CHECKLIST[@]}"; do
    printf '%s\n' "$item"
    printf 'result [y/n/s]: '
    read -r answer || answer=s
    case "$answer" in
      y|Y) ANSWERS+=("PASS|$item"); pass "$item" ;;
      n|N) ANSWERS+=("FAIL|$item"); fail "$item" ;;
      *) ANSWERS+=("SKIP|$item"); skip "$item" ;;
    esac
  done
fi

# ----------------------------------------------------------------------- report
step "report"
{
  echo "# Real-desktop acceptance $STAMP"
  echo
  echo "Host: $(uname -srm) · ${XDG_CURRENT_DESKTOP:-unknown desktop} · ${XDG_SESSION_TYPE:-unknown session}"
  echo
  echo "| Result | Check |"
  echo "| --- | --- |"
  while IFS= read -r line; do
    case "$line" in
      PASS:*) echo "| PASS | ${line#PASS: } |" ;;
      FAIL:*) echo "| FAIL | ${line#FAIL: } |" ;;
      SKIP:*) echo "| SKIP | ${line#SKIP: } |" ;;
    esac
  done < "$SUMMARY"
  echo
  echo "Attach \`$(basename "$REPORT_DIR").tar.gz\` to the repository issue or pull request."
  echo "It contains the environment, session log, screenshots and this report; it contains no credentials."
} > "$REPORT"
cat "$REPORT"

tar -C "$(dirname "$REPORT_DIR")" -czf "$REPORT_DIR.tar.gz" "$(basename "$REPORT_DIR")" 2>/dev/null \
  && note "tarball: $REPORT_DIR.tar.gz"

if [ "$STRICT" -eq 1 ] && [ "$FAILED" -ne 0 ]; then
  exit 1
fi
echo
echo "RESULT: $FAILED failure(s), $SKIPPED skipped. Report: $REPORT"

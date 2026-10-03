#!/usr/bin/env bash
# Exercise the installed application inside a real (headless) desktop session:
#   * a window is actually created and mapped for the application process,
#   * closing the last window does not end the application (the macOS-like behaviour),
#   * a second launch is routed to the running instance instead of starting another one,
#   * a dsh:// activation through the registered handler reaches that instance and brings
#     the window back.
#
# Run it under a display and a session bus, with a window manager on PATH:
#   dbus-run-session -- xvfb-run -a env SHOT_DIR=/tmp ci/desktop-session.sh
#
# Requires: xdotool, a window manager (openbox or fluxbox), imagemagick (optional screenshots).

set -uo pipefail

APP_BIN=${APP_BIN:-/usr/bin/deepseek-harness}
SHOT_DIR=${SHOT_DIR:-.}
MIN_WINDOW_SIZE=${MIN_WINDOW_SIZE:-200}
FAILED=0

note() { echo "[session] $*"; }
fail() { echo "[session] FAIL: $*"; FAILED=1; }

command -v xdotool >/dev/null || { echo "[session] FAIL: xdotool is required" >&2; exit 1; }

# A window manager is needed for WM_DELETE_WINDOW to mean anything.
if command -v openbox >/dev/null; then
  openbox >openbox.log 2>&1 &
elif command -v fluxbox >/dev/null; then
  fluxbox >fluxbox.log 2>&1 &
fi
WM_PID=$!
sleep 2

# A tray/indicator helper window is small and always present, so the assertions look for a
# window of real size and log every window the process owns while they wait.
main_window() {
  local pid=$1 best='' best_area=0 wid area width height
  for wid in $(xdotool search --pid "$pid" 2>/dev/null); do
    eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)"
    area=$(( ${WIDTH:-0} * ${HEIGHT:-0} ))
    [ "${WIDTH:-0}" -ge "$MIN_WINDOW_SIZE" ] && [ "${HEIGHT:-0}" -ge "$MIN_WINDOW_SIZE" ] || continue
    if [ "$area" -gt "$best_area" ]; then best=$wid; best_area=$area; fi
  done
  [ -n "$best" ] && printf '%s' "$best"
}

describe_windows() {
  local pid=$1 wid
  for wid in $(xdotool search --pid "$pid" 2>/dev/null); do
    note "  window $wid name=$(xdotool getwindowname "$wid" 2>/dev/null) $(xdotool getwindowgeometry "$wid" 2>/dev/null | tr '\n' ' ')"
  done
}

"$APP_BIN" >app.log 2>&1 &
APP_PID=$!
note "application pid=$APP_PID"

wid=''
for _ in $(seq 1 60); do
  wid=$(main_window "$APP_PID")
  [ -n "$wid" ] && break
  kill -0 "$APP_PID" 2>/dev/null || break
  sleep 1
done

if [ -z "$wid" ]; then
  fail "no window of at least ${MIN_WINDOW_SIZE}x${MIN_WINDOW_SIZE} appeared for pid $APP_PID within 60s"
  describe_windows "$APP_PID"
  sed 's/^/[session] app.log: /' app.log | tail -20
else
  note "PASS: main window $wid mapped: $(xdotool getwindowname "$wid" 2>/dev/null)"
  xdotool getwindowgeometry "$wid" 2>&1 | sed 's/^/[session] /'
  describe_windows "$APP_PID"
  import -window root "$SHOT_DIR/session-window.png" 2>/dev/null || note "screenshot unavailable"

  xdotool windowclose "$wid" || fail "sending WM_DELETE_WINDOW failed"
  sleep 5
  if kill -0 "$APP_PID" 2>/dev/null; then
    note "PASS: the application kept running after its last window closed"
  else
    fail "the application exited when its last window closed"
  fi
fi

# A later launch must be routed to the owner by the single-instance lock.
"$APP_BIN" >second-launch.log 2>&1 &
SECOND_PID=$!
sleep 8
if kill -0 "$SECOND_PID" 2>/dev/null; then
  fail "the second launch stayed alive instead of exiting on the instance lock"
  kill "$SECOND_PID" 2>/dev/null
else
  note "PASS: the second launch exited, so the running instance owns the lock"
fi
kill -0 "$APP_PID" 2>/dev/null || fail "the owning process died during the second launch"

wid2=''
for _ in $(seq 1 30); do
  wid2=$(main_window "$APP_PID")
  [ -n "$wid2" ] && break
  sleep 1
done
if [ -n "$wid2" ]; then
  note "PASS: the window returned after the second launch ($wid2)"
else
  fail "no window for the owner after the second launch"
fi
import -window root "$SHOT_DIR/session-relaunch.png" 2>/dev/null || true

# dsh:// activation. Close the window first so the check can only pass if the activation
# actually brings it back.
if [ -n "$wid2" ]; then
  xdotool windowclose "$wid2" || fail "could not close the window before the activation check"
  sleep 3
fi

# Registration: the package must own the scheme.
handler=$(xdg-mime query default x-scheme-handler/dsh 2>/dev/null || true)
if [ -n "$handler" ] && [ -f "/usr/share/applications/$handler" ]; then
  note "PASS: x-scheme-handler/dsh is registered to $handler"
else
  fail "x-scheme-handler/dsh is not registered (query returned '$handler')"
fi

# Activation: run the command the registered desktop entry declares, the way a desktop
# environment does when the scheme is opened. gio/xdg-open need a portal or a known desktop
# environment, which a bare Xvfb + openbox session does not provide, so they are only reported.
exec_line=$(grep -m1 '^Exec=' "/usr/share/applications/$handler" 2>/dev/null | cut -d= -f2- || true)
note "desktop entry Exec: ${exec_line:-<none>}"
activation=''
if [ -n "$exec_line" ]; then
  activation=${exec_line//%u/dsh://open}
  activation=${activation//%U/dsh://open}
  activation=${activation//%f/}
  activation=${activation//%F/}
  # shellcheck disable=SC2086 # the entry is a command line, by definition.
  ${activation} >activation.log 2>&1 &
  ACTIVATION_PID=$!
  sleep 10
  if kill -0 "$ACTIVATION_PID" 2>/dev/null; then
    fail "the activation command stayed alive instead of handing over to the running instance"
    kill "$ACTIVATION_PID" 2>/dev/null
  else
    note "PASS: the activation command exited, so the running instance took the request"
  fi
fi
if command -v gio >/dev/null; then
  gio open 'dsh://open' >gio-open.log 2>&1 \
    && note "gio open accepted dsh://open" \
    || note "gio open could not route the scheme here (no desktop portal): $(tr '\n' ' ' <gio-open.log | head -c 120)"
fi
if command -v xdg-open >/dev/null; then
  xdg-open 'dsh://open' >xdg-open.log 2>&1 \
    && note "xdg-open accepted dsh://open" \
    || note "xdg-open could not route the scheme here (no desktop environment): $(tr '\n' ' ' <xdg-open.log | head -c 120)"
fi
sleep 10
kill -0 "$APP_PID" 2>/dev/null || fail "the owner died during dsh:// activation"
if [ -n "$(main_window "$APP_PID")" ]; then
  note "PASS: dsh:// activation reached the running instance and its window is back"
else
  fail "no window after dsh:// activation"
  describe_windows "$APP_PID"
fi
import -window root "$SHOT_DIR/session-deeplink.png" 2>/dev/null || true

if [ -f app.log ]; then tail -20 app.log | sed 's/^/[session] app.log: /'; fi
kill "$APP_PID" 2>/dev/null || true
kill "$WM_PID" 2>/dev/null || true

if [ "$FAILED" -eq 0 ]; then
  echo "SESSION RESULT: PASS"
else
  echo "SESSION RESULT: FAIL"
fi
exit "$FAILED"

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

"$APP_BIN" >app.log 2>&1 &
APP_PID=$!
note "application pid=$APP_PID"

wid=''
for _ in $(seq 1 45); do
  wid=$(xdotool search --pid "$APP_PID" 2>/dev/null | head -1)
  [ -n "$wid" ] && break
  kill -0 "$APP_PID" 2>/dev/null || break
  sleep 1
done

if [ -z "$wid" ]; then
  fail "no window appeared for pid $APP_PID within 45s"
  sed 's/^/[session] app.log: /' app.log | tail -20
else
  note "PASS: window $wid mapped: $(xdotool getwindowname "$wid" 2>/dev/null)"
  xdotool getwindowgeometry "$wid" 2>&1 | sed 's/^/[session] /'
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
for _ in $(seq 1 20); do
  wid2=$(xdotool search --pid "$APP_PID" 2>/dev/null | head -1)
  [ -n "$wid2" ] && break
  sleep 1
done
if [ -n "$wid2" ]; then
  note "PASS: the window returned after the second launch ($wid2)"
else
  fail "no window for the owner after the second launch"
fi
import -window root "$SHOT_DIR/session-relaunch.png" 2>/dev/null || true

# dsh:// activation through the handler the package registered.
if command -v xdg-open >/dev/null; then
  xdg-open 'dsh://open' >xdg-open.log 2>&1 || fail "xdg-open dsh://open failed"
  sleep 8
  kill -0 "$APP_PID" 2>/dev/null || fail "the owner died during dsh:// activation"
  if [ -n "$(xdotool search --pid "$APP_PID" 2>/dev/null | head -1)" ]; then
    note "PASS: dsh:// activation reached the running instance and a window is mapped"
  else
    fail "no window after dsh:// activation"
  fi
  import -window root "$SHOT_DIR/session-deeplink.png" 2>/dev/null || true
  note "xdg-open log: $(tr '\n' ' ' <xdg-open.log 2>/dev/null | head -c 200)"
else
  note "xdg-open unavailable: skipping the activation check"
fi

if [ -f app.log ]; then tail -20 app.log | sed 's/^/[session] app.log: /'; fi
kill "$APP_PID" 2>/dev/null || true
kill "$WM_PID" 2>/dev/null || true

if [ "$FAILED" -eq 0 ]; then
  echo "SESSION RESULT: PASS"
else
  echo "SESSION RESULT: FAIL"
fi
exit "$FAILED"

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

# dsh:// activation through the handler the package registered. Close the window first so the
# check can only pass if the activation actually brought it back.
if [ -n "$wid2" ]; then
  xdotool windowclose "$wid2" || fail "could not close the window before the activation check"
  sleep 3
fi

open_url() {
  if command -v gio >/dev/null; then
    gio open "$1" >gio-open.log 2>&1 && return 0
    note "gio open failed: $(tr '\n' ' ' <gio-open.log 2>/dev/null | head -c 200)"
  fi
  command -v xdg-open >/dev/null || return 127
  xdg-open "$1" >xdg-open.log 2>&1
}

if [ "$(xdotool search --pid "$APP_PID" 2>/dev/null | wc -l | tr -d ' ')" != "0" ] \
  && [ -z "$(main_window "$APP_PID")" ]; then
  note "the window is closed; the activation check now proves it comes back"
fi

if open_url 'dsh://open'; then
  note "the dsh:// handler accepted the request"
else
  fail "no handler accepted dsh://open (xdg-mime query: $(xdg-mime query default x-scheme-handler/dsh 2>&1 | head -c 80))"
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

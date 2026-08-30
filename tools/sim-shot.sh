#!/usr/bin/env bash
# Build the face, run it in the Connect IQ simulator, and save a PNG of the
# watch window.
#
#   tools/sim-shot.sh [output.png] [device]
#   tools/sim-shot.sh --headless shot.png     # no visible window
#
# By default the simulator opens on DISPLAY (:0 here), which the devcontainer
# bind-mounts from the host — so the window appears on your desktop and you can
# drive it by hand while this still captures it. Capture is by window id, not
# screen grab, so the window does not need focus; it does need to be unobscured,
# since plain X11 keeps no pixels for covered windows.
#
# --headless runs it on a private Xvfb display instead: nothing is visible, but
# nothing can obscure it either. Use it when no desktop is attached.
#
# The simulator is single-instance — one already running on another display
# makes the next exit 255 — so any existing one is stopped first.
set -euo pipefail

HEADLESS=0
if [ "${1:-}" = "--headless" ]; then HEADLESS=1; shift; fi

OUT="${1:-sim.png}"
DEVICE="${2:-enduro3}"
SDK="$(ls -d "$HOME"/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-* | sort | tail -1)"
KEY="${MONKEY_KEY:-$HOME/.Garmin/ConnectIQ/developer_key}"
PRG="$(mktemp -d)/face.prg"

if [ "$HEADLESS" = "1" ]; then
    SHOW="${VDISPLAY:-:99}"
    pgrep -f "Xvfb $SHOW" >/dev/null 2>&1 || {
        Xvfb "$SHOW" -screen 0 1400x1000x24 >/dev/null 2>&1 &
        sleep 2
    }
else
    SHOW="${DISPLAY:-:0}"
    DISPLAY="$SHOW" xdpyinfo >/dev/null 2>&1 || {
        echo "display $SHOW is not reachable — retry with --headless" >&2; exit 1; }
fi

echo "==> building for $DEVICE"
monkeyc -f monkey.jungle -d "$DEVICE" -o "$PRG" -y "$KEY" 2>&1 | grep -v '^WARNING' || true

pkill -f "$SDK/bin/simulator" 2>/dev/null || true
sleep 1

echo "==> starting simulator on $SHOW"
DISPLAY="$SHOW" "$SDK/bin/simulator" >/dev/null 2>&1 &
# Wait on the window, not the process: it maps well after the process starts.
for _ in $(seq 30); do
    WIN=$(DISPLAY="$SHOW" xdotool search --name "CIQ Simulator" 2>/dev/null | head -1) && [ -n "$WIN" ] && break
    sleep 1
done
[ -n "${WIN:-}" ] || { echo "simulator window never appeared" >&2; exit 1; }

echo "==> loading app"
DISPLAY="$SHOW" monkeydo "$PRG" "$DEVICE" >/dev/null 2>&1 &
sleep 15   # first draw needs the app loaded and one update tick

DISPLAY="$SHOW" import -window "$WIN" "$OUT"
echo "==> wrote $OUT  (simulator left running on $SHOW)"

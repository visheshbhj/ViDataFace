# Screenshotting the simulator

`tools/sim-shot.sh` builds the watch face, runs it in the Connect IQ simulator,
and writes a PNG of the watch window.

```bash
tools/sim-shot.sh                          # -> sim.png, enduro3
tools/sim-shot.sh screenshots/face.png     # choose the output path
tools/sim-shot.sh shot.png fr965           # choose the device
tools/sim-shot.sh --headless shot.png      # no visible window
```

The simulator is left running afterwards, so you can carry on driving it by
hand — change sensor values under **Simulation**, move the clock, and re-run the
script to capture the result.

## Which display it uses

By default the simulator opens on `$DISPLAY` (`:0` here), which the devcontainer
bind-mounts from the host via `/tmp/.X11-unix`. The window appears on your real
desktop, and the same run captures it.

`--headless` instead starts a private `Xvfb` display (`:99`) and runs the
simulator there. Nothing is visible, which is the point: use it over SSH, in CI,
or on any machine with no X server to forward.

## Why capture by window id

The script finds the window with `xdotool search --name "CIQ Simulator"` and
passes that id to `import -window`. Capturing the window rather than the screen
means **the window does not need focus** — you can work in another app while it
runs.

It does need to be unobscured. Plain X11 keeps no backing store for covered
windows, so anything overlapping the simulator is captured along with it. If
that gets annoying, `--headless` sidesteps it entirely, since nothing can
overlap a window on a display of its own.

## Gotchas

**The simulator is single-instance.** A copy already running — on any display,
including one left over from an earlier session — makes the next one exit `255`
with no error message at all. The script kills any existing simulator first, so
this only bites when launching by hand.

**`xwd -root` does not work here.** It fails with `BadColor` on this X server.
That is why the script uses ImageMagick's `import`; don't swap it back.

**The first draw needs a moment.** The script waits for the window to map, then
sleeps ~15s for the app to load and tick once. A capture taken sooner can catch
a blank or half-drawn face.

## Requirements

`xvfb`, `x11-utils`, `xdotool` and `imagemagick`, all installed by
[`.devcontainer/Dockerfile`](../.devcontainer/Dockerfile). On a container built
before they were added:

```bash
sudo apt-get update && sudo apt-get install -y xvfb x11-utils xdotool imagemagick
```

Captures land in `screenshots/`, which is git-ignored — the tool is tracked, the
frames are not.

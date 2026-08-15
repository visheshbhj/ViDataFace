# Connect IQ Dev Container — Setup

This gives you a Jammy (22.04)-based container where libwebkit2gtk-4.0-37
installs natively, so both the SDK Manager and the Simulator run without the
libsoup2/libsoup3 conflict you hit on Mint 22 (Ubuntu 24.04 base).

VS Code attaches directly INTO this container via the Dev Containers
extension — you edit, build, and run the simulator all from one VS Code
window, no manual `docker run` juggling.

## One-time host setup

1. Install the Dev Containers extension in VS Code:
   Extensions panel -> search "Dev Containers" (publisher: Microsoft) -> Install

2. Allow X11 connections from Docker (needed for the simulator GUI):
   ```bash
   xhost +local:docker
   ```
   Note: this resets on reboot. Either re-run it each session, or add it to
   your ~/.bashrc / a startup script if this becomes your permanent workflow.

3. Make sure these exist on your HOST (they get bind-mounted into the
   container, so the container sees whatever's already here):
   ```bash
   ls ~/.Garmin/ConnectIQ/Sdks/             # your downloaded SDK(s)
   ls ~/.Garmin/ConnectIQ/developer_key     # your dev key (extensionless)
   ls ~/connectiq-sdk-manager/bin/sdkmanager # the SDK Manager binary
   ```
   The key now lives inside `~/.Garmin`, which is already bind-mounted as a
   whole — no separate keys mount needed. `devcontainer.json` points
   `monkeyC.developerKeyPath` at `/home/<your-username>/.Garmin/ConnectIQ/developer_key`
   inside the container (the actual path is built dynamically from your
   host username — see "Username handling" below), matching the filename
   VS Code's Monkey C extension generated (no `.der` extension). If you
   ever regenerate the key and it lands under a different name, update
   that path in `devcontainer.json` to match exactly — Monkey C reads the
   file by exact path, extension doesn't matter as long as it's pointed
   correctly.

   The SDK Manager folder (`~/connectiq-sdk-manager`) is also bind-mounted
   now, so you can launch it from inside the container without needing a
   separate `docker run` session. On container start, a
   `postStartCommand` automatically writes the correct
   `sdkmanager-location.cfg` pointer so you won't hit the "SDK Manager
   path not found" error again — if your `sdkmanager` folder lives
   somewhere other than `~/connectiq-sdk-manager` on the host, update both
   the mount source in `devcontainer.json` and the `postStartCommand`
   path to match.

## Username handling

This config doesn't hardcode a username. `devcontainer.json` reads
`${localEnv:USER}` from your host at build/start time and uses it
everywhere — the container's user, its home directory, the SDK/key mount
targets, and `CIQ_HOME`. In practice this means:

- The container's username and UID/GID match your host user automatically
  (assuming standard UID/GID 1000 for the first account on the machine —
  true for most single-user installs).
- Every path inside your `~/.Garmin` config files (`sdkmanager-location.cfg`,
  `current-sdk.cfg`) that you generated on the host already says
  `/home/<your-username>/...`, and the container now resolves to that
  exact same path — no manual path-fixing needed after a rebuild.
- This template works unmodified if you ever copy it to a different
  machine or a different user account.

If your host UID/GID isn't 1000 (check with `id -u` and `id -g` on your
host), edit the `USER_UID`/`USER_GID` values in `devcontainer.json`'s
`build.args` to match before rebuilding.

## Using it with a project

1. Copy this whole `connectiq-devcontainer` folder's `.devcontainer/`
   subfolder into the ROOT of any Monkey C project you want to work on:
   ```bash
   cp -r ~/connectiq-devcontainer/.devcontainer ~/MyFirstWatchFace/
   ```
   (Repeat for any other project folder — or just keep one canonical
   project folder and create new Monkey C projects inside it later.)

2. Open that project folder in VS Code:
   ```bash
   code ~/MyFirstWatchFace
   ```

3. VS Code should pop up a notification: "Folder contains a Dev Container
   configuration file. Reopen in container?" -> click **Reopen in Container**.

   If it doesn't prompt: `Ctrl+Shift+P` -> "Dev Containers: Reopen in
   Container"

4. First launch builds the image (a few minutes). After that it's cached
   and reopens in seconds.

5. Once attached (VS Code's bottom-left corner will show "Dev Container:
   Connect IQ Dev (<your-project-folder>)"), open a terminal inside VS Code (it's now a container
   shell) and verify:
   ```bash
   ls $CIQ_HOME/Sdks/
   monkeyc --version
   ```
   `monkeyc` should already be on PATH — `postStartCommand` automatically
   symlinks every executable from the current SDK's `bin/` folder into
   `~/.local/bin`, which is on PATH unconditionally via the Dockerfile's
   `ENV PATH` (not `.bashrc`, so it works in every terminal/process, not
   just interactive shells that source it). This re-runs on every
   container start, so it stays correct even after you upgrade the SDK to
   a new version via the SDK Manager — no manual PATH editing needed.

6. Press F5 (Monkey C extension is auto-installed inside the container per
   devcontainer.json) to build and launch the simulator. The simulator
   window will render on your HOST display via the X11 socket mount.

7. To launch the SDK Manager GUI (e.g. to download another device or
   update the SDK), open a terminal inside the container and run:
   ```bash
   ~/connectiq-sdk-manager/bin/sdkmanager &
   ```
   It should render on your host display the same way the simulator does
   — same X11 mount, same libwebkit2gtk-4.0-37 that's now natively
   installed in this container's Jammy base, so the libsoup2/libsoup3
   crash from running it directly on Mint 22 doesn't apply here. Any SDK
   or device updates it downloads land in `~/.Garmin/ConnectIQ/Sdks/`,
   which writes straight back to your host since that's a bind mount.

## Notes

- `--network=host` is used so the simulator's internal communication (it
  talks to monkeyc over a local socket) works without port mapping headaches.
  This does mean the container shares your host's network namespace —
  fine for local dev, just worth knowing.
- `.Garmin` (which now includes your dev key) is bind-mounted, NOT copied —
  anything you do in the container (download a new device via SDK Manager,
  regenerate the key, etc.) writes straight back to your host paths. No
  syncing needed.
- If you update/reinstall the SDK and the folder name changes (version
  bump), nothing manual is needed — `postStartCommand` re-resolves the
  current SDK folder and re-links `~/.local/bin` every time the container
  starts. Just restart the container (or run `Ctrl+Shift+P` ->
  "Dev Containers: Rebuild Container" if you want to force it immediately
  without a full restart).
- If the simulator window doesn't appear at all (vs. erroring), double
  check `xhost +local:docker` was run on the host THIS session, and that
  $DISPLAY is set the same in both host and container (`echo $DISPLAY` in
  both places — should match, usually `:0` or `:1`).

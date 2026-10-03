# Deploying to a watch

Putting the face on a real watch takes two steps. Build a signed `.prg` inside
the devcontainer, then copy it onto the watch over USB from the host.

```bash
monkeyc -f monkey.jungle -d enduro3 -o bin/ViDataFace.prg \
        -y ~/.Garmin/ConnectIQ/developer_key -r
```

Then copy `bin/ViDataFace.prg` into `GARMIN/APPS/` on the watch.

## 1. Build

Run the command above from the project root inside the container.

| Flag | Why |
|---|---|
| `-d enduro3` | The target device. It must be one of the `<iq:product>` entries in `manifest.xml`. |
| `-y …/developer_key` | Signs the build. The watch rejects an unsigned `.prg`. |
| `-r` | Release build. It strips debug info, so the file is smaller and runs leaner. |
| `-o bin/ViDataFace.prg` | Where the output goes. `bin/` is git-ignored. |

A successful build ends with `BUILD SUCCESSFUL`. Expect some `WARNING` lines;
they don't stop the build.

To build for another watch, first add it to `manifest.xml` (in VS Code, use
"Monkey C: Edit Products"). Then pass its id to `-d`.

## 2. Copy it onto the watch

The container has no USB access and no MTP tools, so do this part on the host.
VS Code bind-mounts the project folder into the container, which means the
`.prg` you just built is already in `bin/` of the project folder on the host.

1. Plug the watch in over USB. Garmin watches like the Enduro 3 connect as an
   **MTP** device, not a USB drive.
2. Open it in the file manager. On Linux Mint, Nemo mounts MTP devices
   automatically, and the watch appears in the sidebar. From a terminal you
   can do the same with `gio`:

   ```bash
   gio mount -li | grep -i mtp                  # find the watch's mtp:// URI
   gio copy bin/ViDataFace.prg "mtp://<device>/Internal Storage/GARMIN/APPS/"
   ```

3. Copy `ViDataFace.prg` into **`GARMIN/APPS/`**.
4. Eject the watch and unplug it. It installs the app while it disconnects.
5. On the watch, open **Watch Face** settings and choose ViDataFace.

To update, copy a new build over the old file with the same name. To remove
the face, delete the file from `GARMIN/APPS/`.

## Settings

Garmin Connect only shows settings for apps installed from the Connect IQ
Store, so a sideloaded face is configured on the watch instead. Hold **MENU**,
open **Watch Face**, and choose ViDataFace's customise or settings entry. The
menu is built by [`SettingsMenu`](../source/SettingsMenu.mc):

| Setting | Choices | Default |
|---|---|---|
| Second zone | IST, UTC, London, New York, San Francisco, Dubai, Singapore, Tokyo, Sydney | IST |
| Trend refresh | 5, 10, 15, 20, 30, 45 min, 1 h, 90 min, 2 h, 3 h | 5 min |
| Trend lookback | 1–6 h | 4 h |
| Battery low at | 5–50 % in 5s, then 60–90 % in 10s | 40 % |
| Military time | on / off | off |

A change is written straight away and the face picks it up on its next draw.

## Troubleshooting

**The face doesn't appear in the list.** Check that you built it for the right
device: a `.prg` built for one model won't load on another. Also check that the
file landed in `GARMIN/APPS/` and not in the `GARMIN/` folder above it.

**An "IQ!" icon or a crash on load.** The watch's firmware is probably older
than `minApiLevel` in `manifest.xml` (currently 6.0.2). Update the watch through
Garmin Express or Connect, or lower `minApiLevel` if the code allows it.

**The watch doesn't show up over USB.** Try another cable; many are
charge-only. The watch may also need its USB mode set to MTP or Garmin
(**System → USB Mode**). If the file manager still can't see it, close
Garmin Express, which can hold the connection.

**The signing key is missing.** The key is `~/.Garmin/ConnectIQ/developer_key`
on the host, bind-mounted into the container. See
[`.devcontainer/README.md`](../.devcontainer/README.md). Keep using the same
key: if a build is signed with a different one, the watch treats it as a
different app, so delete the old `.prg` first.

## Sideload vs. the Connect IQ Store

A sideloaded face works like any other, with two limits. The watch drops it if
you reset the watch to factory settings, and it never updates by itself. To
publish through the Store instead, export a `.iq` package with
"Monkey C: Export Project" and upload it on the Connect IQ developer site.

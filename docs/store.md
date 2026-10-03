# Installing through the Connect IQ Store (private beta)

A sideloaded face cannot be configured. On the Enduro 3 its Watch Face menu
offers only **Apply** and **Delete**, and Garmin Connect shows it no settings,
because app settings depend on the app having come from the Store. A **beta**
upload fixes that without publishing anything: a beta is visible only to the
developer account that uploaded it.

## 1. Build the package

```bash
monkeyc -e -r -f monkey.jungle -o bin/ViDataFace.iq \
        -y ~/.Garmin/ConnectIQ/developer_key
```

`-e` packages the app for every device in `manifest.xml` (currently only the
Enduro 3). The Store takes this `.iq` file, not the `.prg`.

**Keep the developer key safe.** Every future upload of this app must be signed
with the same `developer_key`. If it is lost, updates have to go out as a new
app with a new app id, and the settings start over.

## 2. Upload it as a beta

1. Sign in to the Connect IQ developer dashboard,
   [apps-developer.garmin.com](https://apps-developer.garmin.com), with your
   Garmin account.
2. Upload `bin/ViDataFace.iq` as a new app and mark it as a **beta**.
3. Fill in the listing fields the form asks for (name, description, category
   Watch Faces, icon). For a private beta these are seen by no one else.

The form's exact fields have not been walked through for this app; follow what
the dashboard asks for.

## 3. Install it on the watch

1. **Delete the sideloaded copy first**: remove `ViDataFace.prg` from
   `GARMIN/APPS/` over USB. The Store copy has the same app id, and the
   sideloaded file would otherwise stay in its way.
2. After uploading, the dashboard shows the app's page, at an address like
   `https://apps-developer.garmin.com/apps/<app-id>`. Remove `-developer` from
   it, giving `https://apps.garmin.com/apps/<app-id>`.
3. Open that link **on your phone**, signed in to the same Garmin account, and
   install it to the watch. One developer reports that tapping the link only
   worked once they had emailed it to themselves and opened it from the email.
4. Apply ViDataFace from the watch's Watch Face menu.

## 4. Change the settings

Once installed from the Store, the settings in
[`resources/settings/settings.xml`](../resources/settings/settings.xml) appear
for ViDataFace in the phone app's watch face settings. The on-watch menu (see
[settings.md](settings.md)) may also become available in the watch's Watch Face
menu.

Both of these are expected from the Garmin documentation and forums, but have
not yet been seen for ViDataFace. Note what actually appears, so
[settings.md](settings.md) can be updated with the real path.

## Updating

Upload each new `.iq` to the same app on the dashboard, signed with the same
key. Sideloading a `.prg` over a Store-installed copy is expected to put you
back on a sideloaded install, without settings.

## Sources

- [Garmin forums: Settings for a sideloaded app](https://forums.garmin.com/developer/connect-iq/f/discussion/429848/solved-settings-connect-iq-app-for-sideloaded-app---is-this-possible)
- [Garmin forums: How does one install a beta app?](https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/427577/how-does-one-install-a-beta-app)
- [Garmin forums: New Developer FAQ](https://forums.garmin.com/developer/connect-iq/w/wiki/4/new-developer-faq)

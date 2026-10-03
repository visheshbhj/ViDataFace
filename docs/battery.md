# Update cadence and battery

The face runs on two clocks. Each exists because the thing it drives changes
at a different rate, and none of them is the rate the system offers.

| Cadence | What it drives | Constant |
|---|---|---|
| 1 minute | reading every sensor | `Frame.begin()` |
| 5 minutes–3 hours (setting, default 15 min) | the barometric trend | `Settings.trendRefreshMin` |

## The problem

The system asks a watch face to redraw **once a second** while the wrist is
raised, and once a minute otherwise. This face shows no seconds. Four out of
five of those raised-wrist redraws repainted a picture identical to the last
one — and each of them re-read the whole sensor set to do it.

A single draw used to cost:

- 3 × `Activity.getActivityInfo()`
- 3 × `ActivityMonitor.getInfo()`
- ~6 × `System.getDeviceSettings()`
- 2 × `Weather.getCurrentConditions()`
- 2 × `System.getSystemStats()`
- 1 × body battery history iterator
- 1 × `new Position.Location` + `Time.Gregorian.localMoment()`

That last one is the expensive one: resolving a zone means asking the device
for its offset and daylight saving rules. It was being rebuilt from scratch
sixty times a minute to produce the same `IST 06:36`.

## 1 minute — `Frame`

[`Frame`](../source/Frame.mc) takes one snapshot per minute and every module
reads from it. Nothing on this face changes faster than the minute it displays,
so nothing needs asking more often.

The only per-tick call left is `getClockTime()`, which is what detects the
minute rolling over.

Apart from `getDeviceSettings()`, which every draw needs for the clock format,
the sources are **lazy**: `Frame.activity()`, `monitor()`, `stats()`,
`conditions()`, `profile()` and `bodyBattery()` each read their source the
first time they are called in a minute, and not at all otherwise. Most fields
are served by complications, so on a typical minute only the activity monitor
is read (night mode needs it for `isSleepMode`). The others are read only when
their complication is missing. In the simulator that includes the weather:
`COMPLICATION_TYPE_CURRENT_WEATHER` is unavailable there, so the weather icon
falls back to `conditions()`. A logged run showed exactly those two sources
read per minute, and nothing else.

Two things to know if you touch it:

- **`Frame.begin()` must run before anything reads a sensor.** `onShow()` calls
  it explicitly, because it runs before the first draw and `NightMode` would
  otherwise dereference a null snapshot.
- **Settings changes call `Frame.invalidate()`** from `onSettingsChanged`, so a
  new zone or unit appears at once instead of waiting for the minute to roll.

## Every tick — painting

`onUpdate` paints the whole face on every tick the system sends. Only the
sensor reads are rationed (to `Frame`'s minute); drawing is not.

An earlier version painted only every fifth second and returned early
otherwise, relying on the previous frame staying on screen. It does in the
simulator. **On the watch it does not:** the screen is not kept between
`onUpdate` calls, so every skipped tick showed as a blank frame — the face
flashed off once a second while the wrist was raised. Do not gate drawing on a
real device; if drawing itself ever needs to get cheaper, render into a
`BufferedBitmap` and blit that each tick instead.

## 5 minutes–3 hours — the trend

[`Trend`](../source/Trend.mc) reports a pressure change measured across a window
of **1–6 hours** (setting, default 4), from a sensor the device samples every
**two minutes**. Recomputing it on a display cadence was never meaningful; how
often it does is also a setting, 5 minutes to 3 hours.

How the change is worked out is a third setting, **Trend method**:

- **First & last** compares the newest reading with the oldest. Only
  the two ends matter, so each history is opened twice, once oldest-first and
  once newest-first, and only the front sample of each is read: about four
  samples per recompute. It used to walk every sample in the window, up to 180
  each for pressure and elevation (121 each at the default four hours). A
  logged run of both versions side by side returned identical endpoints.
- **All samples** (default) fits a least-squares line through every reading
  in the window and takes the change along it. One noisy reading at either end
  no longer swings the result, but it walks the whole window again (121
  samples per history at four hours, each corrected with a `Math.pow`). That
  is the cost the first method was written to avoid, which is why it is paired
  with a 15-minute default refresh: a third of the scans the old 5-minute
  default would make. A logged simulator run matched an independent Python fit
  of the same samples to within Float rounding (−0.4997 hPa both).

## Night mode stops work, not just drawing

[`NightMode`](../source/NightMode.mc) drops the complication subscriptions on the
way into night and takes them out again on the way out, tracked by a flag so it
happens once at the transition. While asleep the face reads no sensors and
draws no battery arc — three rows of text and nothing else. The cached
complication readings are dropped with the subscriptions: nothing refreshes
them overnight, and the night screen used to show yesterday's date after
midnight.

The face follows the state the **watch** is in, tried in order:

1. `ActivityMonitor.Info.isSleepMode`, **only when it is true**. It is
   deprecated ("may be removed after System 4"), and on a real Enduro 3 the
   night screen never came on, although the simulator reports it correctly.
   So a false from it is not believed.
2. `DeviceSettings.doNotDisturb`. Garmin's sleep mode turns Do Not Disturb on
   (an option in the watch's sleep mode settings), so this is the watch's sleep
   state as Connect IQ can still see it. Turning DND on by hand brings the night
   screen too.
3. The configured sleep window from `UserProfile`, only on a device that reports
   neither. It fires during a late evening inside the window whether or not
   anyone is asleep, which is why it is the last resort.

Reading `isSleepMode` through `Frame.monitor()`, an untyped accessor, suppresses
the compiler's deprecation warning; the deprecation is real regardless.

Verified in the simulator with its Sleep Mode and Do Not Disturb toggles: each
one alone brings the night screen within a minute, and clearing both brings back
the full face with every reading filled.

It is checked once a minute like everything else, so a transition reaches the
screen within a minute of the watch entering or leaving sleep mode.

## Complications

Every field that has a complication uses it, falling back to the sensor path.
That is a battery matter as well as a data one: a complication is pushed by the
device when it changes, rather than polled.

Each subscription is wrapped in its own `try`/`catch`. This is not defensive
padding — `COMPLICATION_TYPE_CURRENT_WEATHER` **throws** from
`subscribeToUpdates` in the simulator, and before it was isolated that took the
whole face down with an error screen at `onShow`. One unsupported type must not
cost the other eleven.

## Per-draw work

Everything on a draw is either cached or cheap:

- Settings, including the military-time flag, are read once a minute by
  [`Settings`](../source/Settings.mc), never from `Properties` on a draw.
- The fallback date text is cached per minute. The view builds it as a
  fallback on every draw even when the date complication is present.
- The labels are drawn from a const array, `Layout.LABEL_KEYS`, rather than
  allocating `LABELS.keys()` each time.
- The complication callback looks its field up in a reverse map built once.
  Heart rate can push many times a minute, and each push used to allocate and
  scan the key array.

## What this is not

**These are counted reductions, not measured battery savings.** The call counts
above are real, but actual current draw can only be measured on the watch.
Nothing here has been tested against a battery.

Two larger levers are left, each with a cost:

- **Complication subscriptions.** Twelve are held whenever the face is not in
  night mode. Each push, heart rate
  above all, wakes the app to run the callback, even though the face only shows
  the value at its next draw. Reading them with `getComplication()` once a
  minute instead would remove those wake-ups, but values would only update once
  a minute while the wrist is raised.
- **Vector fonts on every tick.** While the wrist is raised the whole face is
  repainted each second: about twenty strings in scalable fonts, which cost
  more to render than bitmap fonts. Drawing the face into a `BufferedBitmap`
  once per change and copying that each tick would cut it to one blit, at the
  cost of a full-screen buffer in graphics memory and more code.

## Changing the cadences

The sensor minute is fixed in `Frame.begin()`. The trend's refresh and window
are user settings, read once a minute by [`Settings`](../source/Settings.mc)
alongside the rest of `Frame`'s snapshot.

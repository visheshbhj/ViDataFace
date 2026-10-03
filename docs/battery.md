# Update cadence and battery

The face runs on two clocks. Each exists because the thing it drives changes
at a different rate, and none of them is the rate the system offers.

| Cadence | What it drives | Constant |
|---|---|---|
| 1 minute | reading every sensor | `Frame.begin()` |
| 5 minutes–3 hours (setting, default 5 min) | the barometric trend | `Settings.trendRefreshMin` |

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
often it does is also a setting, 5 minutes to 3 hours. A longer refresh saves scans,
and the trend barely moves in between either way. Each recompute scans ~360 history
samples across two `SensorHistory` iterators, so it is the most expensive thing
on the face when it does run.

## Night mode stops work, not just drawing

[`NightMode`](../source/NightMode.mc) drops the complication subscriptions on the
way into night and takes them out again on the way out, tracked by a flag so it
happens once at the transition. While asleep the face reads no sensors and
draws no battery arc — three rows of text and nothing else.

The trigger is `ActivityMonitor.Info.isSleepMode` — the state the watch itself
is in — falling back to the configured sleep window from `UserProfile` when that
returns null. `isSleepMode` is deprecated and typed `Boolean or Null`, so the
fallback is not hypothetical. Note that reading it through `Frame.monitor`, an
untyped var, suppresses the compiler's deprecation warning; the deprecation is
real regardless.

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

## What this is not

**These are counted reductions, not measured battery savings.** The call counts
above are real, but actual current draw can only
be measured on the watch. Nothing here has been tested against a battery.

The largest remaining lever is untouched: the face still accepts every 1 Hz tick
and returns from it quickly, rather than using `onPartialUpdate` or asking for
fewer wake-ups. That changes how the face behaves when you raise your wrist, so
it is a design decision rather than a free win.

## Changing the cadences

The sensor minute is fixed in `Frame.begin()`. The trend's refresh and window
are user settings, read once a minute by [`Settings`](../source/Settings.mc)
alongside the rest of `Frame`'s snapshot.

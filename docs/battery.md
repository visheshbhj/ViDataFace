# Update cadence and battery

The face runs on three clocks. Each exists because the thing it drives changes
at a different rate, and none of them is the rate the system offers.

| Cadence | What it drives | Constant |
|---|---|---|
| 5 seconds | painting the screen | `ViDataFaceView.DRAW_EVERY_SEC` |
| 1 minute | reading every sensor | `Frame.begin()` |
| 5 minutes | the barometric trend | `Trend.REFRESH_MIN` |

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

## 5 seconds — the draw gate

`onUpdate` returns early unless the five-second step has come round **or the
minute has rolled over**. The second condition is not optional: without it a
minute change landing at `:01` would not reach the screen until `:05`, and the
clock would read stale.

Returning early means `View.onUpdate(dc)` is never called, so `dc.clear()` never
runs and **the previous frame stays on screen**. That is the mechanism — the
face is not redrawn dimmer or partially, it is simply not redrawn.

Verified in the simulator: the face renders normally across skipped ticks, and
a temporary counter read `ticks 5 draws 2`. The skipped draws are genuinely
skipped, not merely cheap.

`Frame.begin()` still runs on every tick, ahead of the gate, because the gate
reads the clock it refreshes. On a tick where the minute has not changed that is
one call and a comparison.

## 5 minutes — the trend

[`Trend`](../source/Trend.mc) reports a pressure change measured across **four
hours**, from a sensor the device samples every **two minutes**. Recomputing it
on a display cadence was never meaningful. Each recompute scans ~360 history
samples across two `SensorHistory` iterators, so it is the most expensive thing
on the face when it does run.

## Night mode stops work, not just drawing

[`NightMode`](../source/NightMode.mc) drops the complication subscriptions on the
way into night and takes them out again on the way out, tracked by a flag so it
happens once at the transition. While asleep the face reads no sensors and
draws no battery arc — three rows of text and nothing else.

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
above are real and the draw gating is verified, but actual current draw can only
be measured on the watch. Nothing here has been tested against a battery.

The largest remaining lever is untouched: the face still accepts every 1 Hz tick
and returns from it quickly, rather than using `onPartialUpdate` or asking for
fewer wake-ups. That changes how the face behaves when you raise your wrist, so
it is a design decision rather than a free win.

## Changing the cadences

All three are single constants. Raising the draw interval past ~15 s is
unlikely to help much — the minute-boundary rule already forces a paint whenever
the display would otherwise be wrong, so the gate is only skipping repaints of
an unchanged picture either way.

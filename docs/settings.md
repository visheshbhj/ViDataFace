# Settings

ViDataFace has seven settings. Whether you can change them depends on how the
face was installed.

## Where to change them

**Sideloaded** (`ViDataFace.prg` copied over USB): nowhere. On the Enduro 3, a
sideloaded face's entry in the Watch Face menu offers only **Apply** and
**Delete**. Garmin Connect shows no settings for it either, because app
settings depend on the app having come from the Store. The face runs on the
defaults in the table below.

**From the Connect IQ Store**, as a private beta (see [store.md](store.md)):
the settings appear in the phone app's settings for the watch face. ViDataFace
also provides an on-watch settings menu; the simulator opens it and it works,
and the watch may offer it from its Watch Face menu once the face comes from
the Store. Neither path has been seen on the watch yet, so record where they
turn up here.

The on-watch menu, wherever it appears, lists the seven settings with their
current values. Select one to see its choices, select a choice to save it, and
you are taken back to the list. A change is saved as soon as you pick it, and
the face uses it on its next redraw.

## Buttons

The Enduro 3 manual names the buttons by position:

| Button | Press | Hold |
|---|---|---|
| Upper-left | Light | Controls menu |
| Middle-left | Scroll up | Main menu |
| Lower-left | Scroll down | |
| Upper-right | Select | |
| Lower-right | Back | |

## The settings

| Setting | Choices | Default |
|---|---|---|
| Second zone | IST, UTC, London, New York, San Francisco, Dubai, Singapore, Tokyo, Sydney | IST |
| Sea-level pressure | On, Off | On |
| Trend refresh | 5, 10, 15, 20, 30, 45 min, 1 h, 90 min, 2 h, 3 h | 15 min |
| Trend lookback | 1, 2, 3, 4, 5, 6 h | 4 h |
| Trend method | First & last, All samples | All samples |
| Battery low at | 5–50 % in steps of 5, then 60, 70, 80, 90 % | 40 % |
| Military time | On, Off | Off |

### Second zone

The time zone shown under the clock, labelled with its short code
(`IST 20:15`). Each zone follows its own daylight saving changes. Connect IQ
cannot read the time zones set on the watch itself, so the zone is picked
here.

### Sea-level pressure

Which pressure the face shows, in hPa:

- **On** (default): pressure corrected to sea level, the figure weather
  forecasts use. It stays put as you climb or descend, so a change in it is
  the weather. This is the watch's own calculation; the face only reads it,
  and shows it **live**, as the watch updates it.
- **Off**: pressure as measured where you stand. It drops about 12 hPa for
  every 100 m you climb, so on a hike it tracks your altitude as much as the
  weather. It updates at each **Trend refresh**, and the face stops listening
  for live sea-level updates it would not show.

The arrow beside it always shows the weather trend, whichever is shown: it is
worked out from readings corrected for altitude.

### Trend refresh

How often the arrow beside the pressure is recalculated. The arrow describes
a change over hours, so a long refresh loses little: anything from 15 minutes
to an hour is a reasonable choice. A longer refresh means less work for the
watch, which matters most with **All samples**.

With **Sea-level pressure** off, the number is updated on the same refresh, so
while you climb it can be up to one refresh behind your altitude.

### Trend lookback

How far back the arrow looks: the pressure now is compared with the pressure
this many hours ago. The watch keeps six hours of history, hence the limit.

The arrow's thresholds grow with the lookback. A change counts as rising or
falling at 0.15 hPa per hour of lookback, and as rapid (a double arrow) at
0.625 hPa per hour: 0.6 and 2.5 hPa at the default four hours.

Short lookbacks react sooner but are noisier. Climbing or descending does not
register as a weather change, because every reading is corrected for altitude.

### Trend method

How the change is worked out:

- **First & last** compares the newest reading with the oldest one in the
  lookback. It reads about four readings, so it is the cheapest, but one odd
  reading at either end can swing the arrow.
- **All samples** fits a straight line through every reading in the lookback
  (121 at the default four hours) and uses the change along that line. It is
  steadier, but each refresh does far more work, so pair it with a longer
  refresh.

The two can disagree near a threshold. On one simulator run, First & last
showed a falling arrow (−0.85 hPa over four hours) and All samples showed none
(−0.50 hPa, below the 0.6 hPa threshold).

### Battery low at

The battery ring around the edge is neon green, and turns sunlight yellow at
or below this level.

### Military time

Shows the time as `1430` instead of `14:30`. It only applies while the watch is
on a 24-hour clock; on a 12-hour clock the face shows `2:30` with `PM` beside it.

## Set on the watch, not here

- **12- or 24-hour time** follows the watch's own time format setting.
- **Units** follow the watch: altitude in metres or feet, temperature in °C or
  °F. Pressure is always hPa, because Connect IQ offers no pressure unit
  setting to follow.

## Night screen

While the watch is asleep, ViDataFace switches to a minimal clock, date and
second zone, and stops reading sensors. It has no on/off setting. It turns on
when the watch reports either of these:

1. **Sleep mode**, through a Connect IQ value that Garmin has deprecated. The
   simulator reports it, but on a real Enduro 3 it did not turn the night
   screen on.
2. **Do Not Disturb**, switched from the controls menu (hold the upper-left
   button). In the simulator, turning it on brings up the night screen within
   a minute and turning it off brings back the full face. This is still to be
   confirmed on the watch.

On the Enduro 3, sleep is a **Focus Mode** (hold the middle-left button, then
**Watch Settings > Focus Modes > Sleep**). Two of its options matter here:

- **Watch Face** chooses the face shown while the Sleep focus is on. It must
  be ViDataFace, or the night screen is never seen.
- **Notifications & Alerts.** The manual does not say whether the Sleep focus
  raises the Do Not Disturb flag that ViDataFace reads. If the night screen
  does not appear during sleep, this is the likely reason. Turning on Do Not
  Disturb by hand at bedtime works around it.

On a watch that reports neither, the face falls back to the sleep schedule
(the bed and wake times in Garmin Connect or the Sleep focus). The simulator's
Enduro 3 reports Do Not Disturb, so the fallback should not come into play
there.

## Troubleshooting

**Only Apply and Delete in the Watch Face menu.** The face is sideloaded, so
it has no settings. Install it from the Store as a beta instead
([store.md](store.md)).

**A setting seems to have no effect.** The arrow (and, with Sea-level pressure
off, the number) changes only at its next refresh, unless one of the pressure
settings itself changes, which updates it at once. With a 3-hour refresh it
can be up to three hours old.

**Settings reset after an update.** Installing a newer Store version of the
same app is expected to keep its settings, but this has not been checked on
the watch. If they reset, set them again.

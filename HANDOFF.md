# Enduro 3 Watch Face — Implementation Handoff

Garmin Enduro 3 (280 × 280 MIP, round). Connect IQ watch face.
Layout is **Pass 6a**, locked. Companion file: `Layout.mc` (drop-in module with
all anchors, inks, formatters, and the battery arc).

---

## 1. Canvas & fields

280 × 280, centre (140, 140). Eleven data fields, no overlap, no captions on
altitude/barometer (values only).

| Field | Anchor (x, y) | Justify | Size px | Colour | Notes |
|---|---|---|---|---|---|
| Battery arc | 140, 140 · r=132 | — | pen 5 | `#F2F4F0` on `#2A2F2A` track | starts 12 o'clock, clockwise |
| Weather icon | 112, 44 | centre | 28 × 28 | `#F2F4F0` | bitmap, see §5 |
| Temperature | 132, 44 | **left** | 22 | `#F2F4F0` | left edge sits beside icon |
| Altitude | 74, 86 | centre | 18 | `#F2F4F0` | value + `m`, no label |
| Barometer | 206, 86 | centre | 18 | `#F2F4F0` | hPa, no label |
| Clock | 140, 122 | centre | 54 | `#FFFFFF` | primary element |
| 2nd timezone (IST) | 140, 162 | centre | 14 | `#9AA79F` | mono |
| CAL label / value | 66, 182 / 66, 199 | centre | 10 / 18 | `#78877D` / `#F2F4F0` | |
| HR label / value | 140, 182 / 140, 199 | centre | 10 / 18 | `#78877D` / `#FF4A33` | |
| STEPS label / value | 214, 182 / 214, 199 | centre | 10 / 18 | `#78877D` / `#F2F4F0` | full count to 99999 |
| BODY label / value | 66, 225 / 66, 242 | centre | 10 / 17 | `#78877D` / `#F2F4F0` | |
| SOLAR label / value | 140, 225 / 140, 242 | centre | 10 / 17 | `#A98B45` / `#FFAA00` | intensity 0–150%+ |
| STRESS label / value | 214, 225 / 214, 242 | centre | 10 / 17 | `#78877D` / `#F2F4F0` | |

All coordinates are the **anchor point** passed to `dc.drawText()`, with
`TEXT_JUSTIFY_CENTER | TEXT_JUSTIFY_VCENTER` (except temperature, which is
`TEXT_JUSTIFY_LEFT | TEXT_JUSTIFY_VCENTER`).

Row rhythm: clock 122 → IST 162 → metric row 182/199 → bottom row 225/242.
That leaves 8 px above the metric row and 12 px between the two lower rows.
Bottom row uses the **same columns as the metric row** (66/140/214, 74 px pitch)
— the earlier 52 px pitch collided under stock fonts.

## 2. Ink

Four inks only. Tuned for backlit and low-light readability on MIP.

```
INK_BRIGHT = 0xF2F4F0   // primary values
INK_WHITE  = 0xFFFFFF   // clock only
INK_DIM    = 0x78877D   // labels
INK_MID    = 0x9AA79F   // second timezone
INK_HR     = 0xFF4A33   // heart rate value
INK_SOLAR  = 0xFFAA00   // solar value
INK_SOLARL = 0xA98B45   // solar label
INK_TRACK  = 0x2A2F2A   // battery arc track
Background = 0x080A08
```

## 3. Value formatting — the #1 source of bugs

Garmin APIs return **Float**, not Number. Passing an API value straight to
`drawText()` prints `5.765788`, `24.0000`, `838.00000`. Always format:

```monkeyc
Layout.altitude(info.altitude)   // Float metres  -> "1247m"
Layout.pressure(info.pressure)   // PASCALS       -> "1013"   (divide by 100)
Layout.temp(cond.temperature)    // Float C       -> "12°"    (keeps minus sign)
Layout.pct(stats.stress)         //               -> "43%"
Layout.num(info.steps)           //               -> "8421"
```

- **Barometer is in Pascals.** 83800 Pa → 838 hPa. Divide by 100.
- Every formatter is null-safe and returns `"--"` when the sensor has no value.
- Negatives: keep the sign, drop nothing (`-12°`, `-340m`).
- Overflow: steps to 99999, solar to 150%+, altitude to 5 digits.

## 4. Drawing

```monkeyc
using Toybox.Graphics as Gfx;

function onUpdate(dc) {
    dc.setColor(Gfx.COLOR_TRANSPARENT, 0x080A08);
    dc.clear();

    Layout.battery(dc, stats.battery);

    Layout.put(dc, :clock,      clockString());
    Layout.put(dc, :timezone_2, istString());
    Layout.put(dc, :altitude,   Layout.altitude(info.altitude));
    Layout.put(dc, :barometer,  Layout.pressure(info.pressure));
    Layout.put(dc, :temperature, Layout.temp(cond.temperature));

    Layout.label(dc, :hr_label);
    Layout.put(dc, :hr_value, Layout.num(info.heartRate));
    // …same shape for cal / steps / body / solar / stress
}
```

`Layout.put(dc, key, text)` resolves anchor + justify + colour + font from the
`ANCHORS` dictionary. `Layout.label(dc, key)` draws the short label form.

## 5. Fonts & glyphs

Font slots in `Layout.mc` are stock placeholders — swap for custom `.fnt`
resources to hit the design metrics exactly (stock fonts run wider):

```
F_CLOCK 54 | F_TEMP 22 | F_VALUE 18 | F_VALUE_SM 17 | F_TZ 14 | F_LABEL 10
```

Two custom bitmap glyphs are wanted but **not yet drawn**: `♥` (HR) and a
footprint (steps). Until then the text labels HR / STEPS stand in.

Weather icons: 54 SVGs at 24 × 24 viewBox, one per Garmin
`CONDITION_*` enum value, named `NN-condition.svg` by enum number
(`00-clear.svg` … `53-unknown.svg`). **Rasterise each at the exact pixel size
you'll draw it** — 24, 30 and 44 px — don't scale a single PNG.

## 6. Open items

- **Barometer trend chevrons** (rapid/gradual up/down) are spec'd but not drawn.
  Polygon vertices are ready if wanted.
- **Clock gutters**: ~48 px free each side of the clock, deliberately empty.
  Candidates if it ever needs filling: sunset, ascent, a third timezone.
- HR/steps bitmap glyphs (above).

## 7. Project files

- `Layout.mc` — the module described here. Drop into `source/`.
- `enduro3-face-coordinates.csv` — same anchor table, machine-readable.
- `weather-icons-svg/` — 54 condition icons.
- `Enduro 3 Watch Face.dc.html` — visual reference, Pass 6a + earlier passes.
- `Watch Face Spec.dc.html` — annotated spec, 18 anchors. Note: y-values in this
  doc still reflect the pre-6a rhythm; `Layout.mc` is the source of truth.

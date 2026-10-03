import Toybox.Application;
import Toybox.Lang;

//! The user's numeric settings, read once a minute with the rest of Frame's
//! snapshot rather than on every draw. Each is clamped to the range the
//! settings page offers, so a stale or hand-edited value can't reach the face
//! out of range.
module Settings {

    // Barometric trend: how often it is recomputed, and how far back it looks.
    // The watch keeps six hours of pressure history, hence the cap.
    var trendRefreshMin = 15;
    var trendWindowHours = 4;
    // Trend.METHOD_ENDS (first and last reading) or Trend.METHOD_FIT (every
    // reading in the window).
    var trendMethod = 1;

    // Pressure shown corrected to sea level (true) or as measured where you
    // stand (false), which changes with altitude.
    var pressureSeaLevel = true;

    // The battery ring turns from green to yellow at or below this.
    var batteryLowPct = 40;

    // Index into SecondZone.ZONES.
    var secondZone = 0;

    // "1430" rather than "14:30" on a 24-hour watch.
    var militaryTime = false;

    function load() as Void {
        trendRefreshMin  = number("TrendIntervalMin", 5, 180, 15);
        trendWindowHours = number("TrendWindowHours", 1,   6,  4);
        trendMethod      = number("TrendCalc",        0,   1,  1);
        batteryLowPct    = number("BatteryLowPct",    5,  95, 40);
        secondZone       = number("SecondZone",       0, SecondZone.ZONES.size() - 1, 0);
        militaryTime     = Application.Properties.getValue("UseMilitaryFormat") == true;
        pressureSeaLevel = Application.Properties.getValue("PressureSeaLevel") != false;
    }

    function number(key as String, lo as Number, hi as Number,
                    fallback as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v == null || !(v instanceof Number)) {
            return fallback;
        }
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
}

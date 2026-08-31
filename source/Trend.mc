import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

//! Four-hour barometric trend, read from the device's own sensor history.
//!
//! Enduro 3 keeps 180 pressure samples at 120 s — six hours — and the same for
//! elevation, so there is nothing for us to sample or store: the history is
//! already there on first run, survives everything, and costs no flash writes.
//! An earlier version sampled into Application.Storage every five minutes and
//! needed 90 minutes of warm-up before it could say anything; this needs none.
//!
//! The samples are AMBIENT pressure, so they still have to be corrected: a
//! 100 m climb drops ambient about 12 hPa, several times the rapid threshold,
//! and a lift ride would read as a storm front. Each endpoint is normalised to
//! sea level using the elevation history over the same window.
module Trend {

    const WINDOW_SEC   = 4 * 3600;
    // Below this much history the window is too short to call a trend.
    const MIN_SPAN_SEC = 45 * 60;

    // hPa across the window. Meteorology calls ~2 hPa in 3 hours rapid; these
    // are the 4-hour equivalents.
    const GRADUAL_HPA = 0.6;
    const RAPID_HPA   = 2.5;

    // Scanning two histories is ~360 samples. The reading is a change measured
    // across FOUR HOURS, so it cannot move meaningfully in a minute: recomputing
    // every five is still far finer than the quantity being reported.
    const REFRESH_MIN = 5;
    var _marker = null;
    var _slot = -1;

    //! :rapid_up, :up, :down, :rapid_down, or null when the change is too small
    //! to report, the window too short, or the device keeps no pressure history.
    function marker() as Symbol? {
        var slot = Frame.minute() / REFRESH_MIN;
        if (slot != _slot) {
            _slot = slot;
            _marker = compute();
        }
        return _marker;
    }

    function compute() as Symbol? {
        if (!(Toybox has :SensorHistory)
                || !(Toybox.SensorHistory has :getPressureHistory)) {
            return null;
        }
        var pressure = endpoints(Toybox.SensorHistory.getPressureHistory(
            { :period => new Time.Duration(WINDOW_SEC) }));
        if (pressure == null) {
            return null;
        }
        var older = pressure[0] as Array;
        var newer = pressure[1] as Array;
        if (((newer[0] as Number) - (older[0] as Number)) < MIN_SPAN_SEC) {
            return null;
        }

        // Elevation shares the window and the 120 s cadence, so its endpoints
        // line up with the pressure endpoints closely enough to correct them.
        var lowEl = null;
        var highEl = null;
        if (Toybox.SensorHistory has :getElevationHistory) {
            var elevation = endpoints(Toybox.SensorHistory.getElevationHistory(
                { :period => new Time.Duration(WINDOW_SEC) }));
            if (elevation != null) {
                lowEl = (elevation[0] as Array)[1];
                highEl = (elevation[1] as Array)[1];
            }
        }

        var d = (toSeaLevel(newer[1] as Float, highEl)
               - toSeaLevel(older[1] as Float, lowEl)) / 100.0;
        var mag = (d < 0) ? -d : d;
        if (mag < GRADUAL_HPA) {
            return null;
        }
        if (mag >= RAPID_HPA) {
            return (d > 0) ? :rapid_up : :rapid_down;
        }
        return (d > 0) ? :up : :down;
    }

    //! [[oldestSeconds, oldestValue], [newestSeconds, newestValue]] for a
    //! history iterator, or null if it yielded no usable sample.
    function endpoints(iterator) as Array? {
        if (iterator == null) {
            return null;
        }
        var oldest = null;
        var newest = null;
        var s = iterator.next();
        while (s != null) {
            if (s.data != null) {
                var t = s.when.value();
                if (oldest == null || t < (oldest as Array)[0]) { oldest = [t, s.data]; }
                if (newest == null || t > (newest as Array)[0]) { newest = [t, s.data]; }
            }
            s = iterator.next();
        }
        if (oldest == null || newest == null) {
            return null;
        }
        return [oldest, newest];
    }

    //! Ambient pascals at h metres -> pascals at sea level (ISA). A null
    //! elevation leaves the reading alone, which is right when both endpoints
    //! are uncorrected: the difference is still meaningful, just noisier.
    function toSeaLevel(pa as Float, h) as Float {
        if (h == null) {
            return pa;
        }
        return pa / Math.pow(1.0 - 0.0000225577 * (h as Float), 5.25588);
    }
}

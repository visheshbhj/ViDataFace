import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

//! Barometric trend, read from the device's own sensor history. The window
//! (1-6 h, default 4) and how often it is recomputed (5 min-3 h, default 5 min) are
//! user settings; see Settings.
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

    // Below this much history the window is too short to call a trend. It is
    // 45 min whatever the window, which is three quarters of the shortest one.
    const MIN_SPAN_SEC = 45 * 60;

    // hPa PER HOUR of window. Meteorology calls ~2 hPa in 3 hours rapid; these
    // were 0.6 and 2.5 hPa across the original fixed 4-hour window, and scale
    // with the window so a short one is not held to a long one's total.
    const GRADUAL_HPA_PER_H = 0.15;
    const RAPID_HPA_PER_H   = 0.625;

    // Each recompute reads only the two ends of the pressure and elevation
    // histories (see endpoints). The reading is a change measured across
    // hours, so it cannot move meaningfully in a minute.
    var _marker = null;
    var _slot = -1;
    var _refresh = -1;
    var _window = -1;

    //! :rapid_up, :up, :down, :rapid_down, or null when the change is too small
    //! to report, the window too short, or the device keeps no pressure history.
    function marker() as Symbol? {
        var refresh = Settings.trendRefreshMin;
        var window = Settings.trendWindowHours;
        var slot = Frame.minute() / refresh;
        // A changed setting recomputes at once rather than at the next slot.
        if (slot != _slot || refresh != _refresh || window != _window) {
            _slot = slot;
            _refresh = refresh;
            _window = window;
            _marker = compute(window);
        }
        return _marker;
    }

    function compute(hours as Number) as Symbol? {
        var windowSec = hours * 3600;
        if (!(Toybox has :SensorHistory)
                || !(Toybox.SensorHistory has :getPressureHistory)) {
            return null;
        }
        var pressure = endpoints(:pressure, windowSec);
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
            var elevation = endpoints(:elevation, windowSec);
            if (elevation != null) {
                lowEl = (elevation[0] as Array)[1];
                highEl = (elevation[1] as Array)[1];
            }
        }

        var d = (toSeaLevel(newer[1] as Float, highEl)
               - toSeaLevel(older[1] as Float, lowEl)) / 100.0;
        var mag = (d < 0) ? -d : d;
        if (mag < GRADUAL_HPA_PER_H * hours) {
            return null;
        }
        if (mag >= RAPID_HPA_PER_H * hours) {
            return (d > 0) ? :rapid_up : :rapid_down;
        }
        return (d > 0) ? :up : :down;
    }

    //! [[oldestSeconds, oldestValue], [newestSeconds, newestValue]] over the
    //! window, or null if the history has no usable sample.
    //!
    //! Only the two ends are needed, so the history is opened twice, once in
    //! each order, and read from the front. That is a handful of samples rather
    //! than the whole window: six hours at 120 s is 180 per history, and this
    //! used to walk all of them, for both pressure and elevation.
    function endpoints(kind as Symbol, windowSec as Number) as Array? {
        var oldest = first(history(kind, windowSec, Toybox.SensorHistory.ORDER_OLDEST_FIRST));
        if (oldest == null) {
            return null;
        }
        var newest = first(history(kind, windowSec, Toybox.SensorHistory.ORDER_NEWEST_FIRST));
        if (newest == null) {
            return null;
        }
        return [oldest, newest];
    }

    function history(kind as Symbol, windowSec as Number, order) {
        var options = { :period => new Time.Duration(windowSec), :order => order };
        return (kind == :pressure)
            ? Toybox.SensorHistory.getPressureHistory(options)
            : Toybox.SensorHistory.getElevationHistory(options);
    }

    //! [seconds, value] of the first sample with data, or null. Gaps (null
    //! data) are skipped; there are rarely more than one or two in a row.
    function first(iterator) as Array? {
        if (iterator == null) {
            return null;
        }
        var s = iterator.next();
        while (s != null) {
            if (s.data != null) {
                return [s.when.value(), s.data];
            }
            s = iterator.next();
        }
        return null;
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

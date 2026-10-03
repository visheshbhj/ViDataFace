import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

//! Barometric trend, read from the device's own sensor history. The window
//! (1-6 h, default 4), how often it is recomputed (5 min-3 h, default 5 min)
//! and the method are user settings; see Settings. The method is either:
//!
//!   METHOD_ENDS  the newest reading minus the oldest. Four samples read, but
//!                one noisy sample at either end moves the whole result.
//!   METHOD_FIT   a least-squares line through every reading in the window,
//!                and the change along that line across the same span. Steadier,
//!                but it walks the whole window: 121 samples per history at
//!                the default four hours, each corrected with a Math.pow.
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

    // Values of the TrendMethod setting.
    const METHOD_ENDS = 0;
    const METHOD_FIT  = 1;

    // The reading is a change measured across hours, so it cannot move
    // meaningfully in a minute.
    var _marker = null;
    var _slot = -1;
    var _refresh = -1;
    var _window = -1;
    var _method = -1;

    //! :rapid_up, :up, :down, :rapid_down, or null when the change is too small
    //! to report, the window too short, or the device keeps no pressure history.
    function marker() as Symbol? {
        var refresh = Settings.trendRefreshMin;
        var window = Settings.trendWindowHours;
        var method = Settings.trendMethod;
        var slot = Frame.minute() / refresh;
        // A changed setting recomputes at once rather than at the next slot.
        if (slot != _slot || refresh != _refresh || window != _window
                || method != _method) {
            _slot = slot;
            _refresh = refresh;
            _window = window;
            _method = method;
            _marker = compute(window, method);
        }
        return _marker;
    }

    function compute(hours as Number, method as Number) as Symbol? {
        if (!(Toybox has :SensorHistory)
                || !(Toybox.SensorHistory has :getPressureHistory)) {
            return null;
        }
        var windowSec = hours * 3600;
        var d = (method == METHOD_FIT) ? fitChange(windowSec)
                                       : endsChange(windowSec);
        if (d == null) {
            return null;
        }
        var mag = (d < 0) ? -d : d;
        if (mag < GRADUAL_HPA_PER_H * hours) {
            return null;
        }
        if (mag >= RAPID_HPA_PER_H * hours) {
            return (d > 0) ? :rapid_up : :rapid_down;
        }
        return (d > 0) ? :up : :down;
    }

    //! Sea-level hPa change from the oldest reading to the newest, or null
    //! when there is too little history.
    function endsChange(windowSec as Number) as Float? {
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

        return (toSeaLevel(newer[1] as Float, highEl)
              - toSeaLevel(older[1] as Float, lowEl)) / 100.0;
    }

    //! Sea-level hPa change along a least-squares line through every reading
    //! in the window, taken across the span the readings cover: the same span
    //! endsChange measures, so the thresholds mean the same for both. null
    //! when there is too little history.
    //!
    //! Both histories are walked oldest-first in step. Each pressure reading
    //! is corrected with the latest elevation at or before it; the 120 s
    //! cadences match, so that is the same sample or the one just before.
    //! Where the device keeps elevation, a pressure reading with no elevation
    //! to pair yet is skipped rather than left uncorrected: one uncorrected
    //! reading among corrected ones would be off by the full altitude effect.
    function fitChange(windowSec as Number) as Float? {
        var pIt = history(:pressure, windowSec, Toybox.SensorHistory.ORDER_OLDEST_FIRST);
        if (pIt == null) {
            return null;
        }
        var eIt = (Toybox.SensorHistory has :getElevationHistory)
            ? history(:elevation, windowSec, Toybox.SensorHistory.ORDER_OLDEST_FIRST) : null;
        var e = (eIt != null) ? eIt.next() : null;
        var elev = null;

        // Sums for the fit. x is hours since the first reading and y is hPa
        // relative to it, both Double: the raw seconds and pascals are large
        // enough that n*Sxx - Sx*Sx would lose most of its digits in Float.
        var t0 = null;
        var y0 = 0.0d;
        var tLast = 0;
        var n = 0;
        var sx = 0.0d;
        var sy = 0.0d;
        var sxx = 0.0d;
        var sxy = 0.0d;

        var s = pIt.next();
        while (s != null) {
            if (s.data != null) {
                var t = s.when.value();
                while (e != null && e.when.value() <= t) {
                    if (e.data != null) { elev = e.data; }
                    e = eIt.next();
                }
                if (eIt == null || elev != null) {
                    var p = toSeaLevel((s.data as Numeric).toFloat(), elev).toDouble() / 100.0d;
                    if (t0 == null) {
                        t0 = t;
                        y0 = p;
                    }
                    var x = (t - (t0 as Number)).toDouble() / 3600.0d;
                    var y = p - y0;
                    n++;
                    sx += x;
                    sy += y;
                    sxx += x * x;
                    sxy += x * y;
                    tLast = t;
                }
            }
            s = pIt.next();
        }

        if (t0 == null || n < 3 || (tLast - (t0 as Number)) < MIN_SPAN_SEC) {
            return null;
        }
        var den = n * sxx - sx * sx;
        if (den <= 0.0d) {
            return null;
        }
        var slope = (n * sxy - sx * sy) / den;   // hPa per hour
        return (slope * (tLast - (t0 as Number)).toDouble() / 3600.0d).toFloat();
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

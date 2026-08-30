import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Four-hour barometric trend, sampled on the wall clock.
//!
//! Samples land on every SAMPLE_MIN'th minute of the hour (:00, :05, :10 …)
//! rather than every SAMPLE_MIN minutes elapsed, so the series stays aligned
//! across restarts and a missed wake-up does not shift every later slot.
//!
//! What is stored is SEA-LEVEL pressure, never the raw ambient reading. Climbing
//! 100 m drops ambient pressure about 12 hPa — several times the threshold for
//! "rapid fall" — so a lift ride would otherwise read as a storm front. See
//! DataService.seaLevelPressure().
//!
//! History lives in Application.Storage so it survives the face being unloaded,
//! which happens whenever an activity starts.
module Trend {

    // Change to 10 or 15 to sample less often. WINDOW_MIN / SAMPLE_MIN is the
    // number of stored samples, so 5 minutes over 4 hours keeps 48 of them.
    const SAMPLE_MIN   = 5;
    const WINDOW_MIN   = 240;   // 4 hours
    // Below this much history the window is too short to call a trend.
    const MIN_SPAN_MIN = 90;

    // hPa over the window. Meteorological practice calls ~2 hPa in 3 hours a
    // rapid change; these are the 4-hour equivalents.
    const GRADUAL_HPA = 0.6;
    const RAPID_HPA   = 2.5;

    const KEY = "baroHistory";

    //! Record the current sample if this slot has not been recorded yet.
    //! Cheap to call on every update: it writes at most once per slot.
    function sample() as Void {
        var pa = DataService.seaLevelPressure();
        if (pa == null) {
            return;
        }
        var nowMin = Time.now().value() / 60;
        var slot = nowMin / SAMPLE_MIN;

        var hist = history();
        if (hist.size() > 0) {
            var last = hist[hist.size() - 1] as Array;
            if (((last[0] as Number) / SAMPLE_MIN) == slot) {
                return;   // this slot is already in the series
            }
        }

        hist.add([nowMin, pa]);
        Application.Storage.setValue(KEY, prune(hist, nowMin));
    }

    //! The marker for the barometer field: :rapid_up, :up, :down, :rapid_down,
    //! or null when the change is small or the history is too short to judge.
    function marker() as Symbol? {
        var hist = history();
        if (hist.size() < 2) {
            return null;
        }
        var oldest = hist[0] as Array;
        var newest = hist[hist.size() - 1] as Array;
        if (((newest[0] as Number) - (oldest[0] as Number)) < MIN_SPAN_MIN) {
            return null;
        }
        // Pascals to hectopascals: the thresholds are quoted in hPa.
        var d = ((newest[1] as Float) - (oldest[1] as Float)) / 100.0;
        var mag = (d < 0) ? -d : d;
        if (mag < GRADUAL_HPA) {
            return null;
        }
        if (mag >= RAPID_HPA) {
            return (d > 0) ? :rapid_up : :rapid_down;
        }
        return (d > 0) ? :up : :down;
    }

    //! Stored samples, oldest first. Each is [minute, pascals].
    function history() as Array {
        var stored = Application.Storage.getValue(KEY);
        if (stored == null || !(stored instanceof Array)) {
            return [] as Array;
        }
        return stored as Array;
    }

    //! Drop samples that have fallen out of the window. Also drops samples from
    //! the future, which a clock or timezone change can leave behind.
    function prune(hist as Array, nowMin as Number) as Array {
        var cutoff = nowMin - WINDOW_MIN;
        var kept = [] as Array;
        for (var i = 0; i < hist.size(); i++) {
            var t = (hist[i] as Array)[0] as Number;
            if (t >= cutoff && t <= nowMin) {
                kept.add(hist[i]);
            }
        }
        return kept;
    }
}

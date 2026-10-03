import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;
import Toybox.UserProfile;

//! One snapshot of everything the face reads, taken once a MINUTE.
//!
//! A watch face is redrawn once a second while the wrist is raised, and once a
//! minute otherwise. Nothing this face shows changes faster than the minute it
//! displays — there is no seconds hand — so re-reading sensors on every draw
//! did the same work sixty times over for an identical picture.
//!
//! Before: each draw made three Activity.getActivityInfo() calls, three
//! ActivityMonitor.getInfo(), six getDeviceSettings(), two weather reads and a
//! SensorHistory scan. Now each is made once per minute and shared.
//!
//! The sources other than settings are also LAZY: each is read the first time
//! something asks for it in a minute, and not at all otherwise. Most fields are
//! served by complications, so a source is read only when a complication it
//! backs is missing. With all of them present, only the activity monitor is
//! read each minute, for night mode's isSleepMode.
module Frame {

    // Refreshed every draw: it is one cheap call and it drives the minute check.
    var clock = null;

    // Refreshed once a minute: the clock format is needed on every draw.
    var settings = null;

    // Read on first use in a minute; see the accessors below.
    var _activity = null;
    var _monitor = null;
    var _stats = null;
    var _conditions = null;
    var _profile = null;
    var _bodyBattery = null;
    // Bit per source above: set once it has been read this minute.
    var _read = 0;

    const ACTIVITY = 1;
    const MONITOR = 2;
    const STATS = 4;
    const CONDITIONS = 8;
    const PROFILE = 16;
    const BODY_BATTERY = 32;

    var _minute = -1;

    //! Call once at the top of onUpdate.
    function begin() as Void {
        clock = System.getClockTime();
        var minute = clock.hour * 60 + clock.min;
        if (minute == _minute && settings != null) {
            return;
        }
        _minute = minute;

        Settings.load();
        settings = System.getDeviceSettings();
        _read = 0;
    }

    //! True the first time a source is asked for this minute, marking it read.
    function first(bit as Number) as Boolean {
        if ((_read & bit) != 0) {
            return false;
        }
        _read |= bit;
        return true;
    }

    function activity() {
        if (first(ACTIVITY)) { _activity = Activity.getActivityInfo(); }
        return _activity;
    }

    function monitor() {
        if (first(MONITOR)) { _monitor = ActivityMonitor.getInfo(); }
        return _monitor;
    }

    function stats() {
        if (first(STATS)) { _stats = System.getSystemStats(); }
        return _stats;
    }

    function conditions() {
        if (first(CONDITIONS)) {
            _conditions = (Toybox has :Weather)
                ? Toybox.Weather.getCurrentConditions() : null;
        }
        return _conditions;
    }

    function profile() {
        if (first(PROFILE)) { _profile = UserProfile.getProfile(); }
        return _profile;
    }

    //! Body battery is a history iterator, not a plain getter, so it is the
    //! most expensive of these to ask for twice. Newest-first, so one next()
    //! is the current value.
    function bodyBattery() {
        if (first(BODY_BATTERY)) {
            _bodyBattery = null;
            if ((Toybox has :SensorHistory)
                    && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var sample = Toybox.SensorHistory.getBodyBatteryHistory(
                    { :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST }).next();
                if (sample != null && sample.data != null) {
                    _bodyBattery = sample.data;
                }
            }
        }
        return _bodyBattery;
    }

    //! The minute this snapshot belongs to, for anything keeping its own cache
    //! in step with it.
    function minute() as Number {
        return _minute;
    }

    //! Force the next begin() to re-read. The app calls this when settings
    //! change, so a new zone or unit does not wait for the minute to roll over.
    function invalidate() as Void {
        _minute = -1;
    }
}

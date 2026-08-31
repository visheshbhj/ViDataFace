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
module Frame {

    // Refreshed every draw: it is one cheap call and it drives the minute check.
    var clock = null;

    // Refreshed once a minute.
    var settings = null;
    var activity = null;
    var monitor = null;
    var stats = null;
    var conditions = null;
    var profile = null;
    var bodyBattery = null;

    var _minute = -1;

    //! Call once at the top of onUpdate.
    function begin() as Void {
        clock = System.getClockTime();
        var minute = clock.hour * 60 + clock.min;
        if (minute == _minute && settings != null) {
            return;
        }
        _minute = minute;

        settings = System.getDeviceSettings();
        activity = Activity.getActivityInfo();
        monitor = ActivityMonitor.getInfo();
        stats = System.getSystemStats();
        profile = UserProfile.getProfile();
        conditions = (Toybox has :Weather)
            ? Toybox.Weather.getCurrentConditions() : null;

        // Body battery is a history iterator, not a plain getter, so it is the
        // most expensive of these to ask for twice.
        bodyBattery = null;
        if ((Toybox has :SensorHistory)
                && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
            var sample = Toybox.SensorHistory.getBodyBatteryHistory({}).next();
            if (sample != null && sample.data != null) {
                bodyBattery = sample.data;
            }
        }
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

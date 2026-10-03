import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;

//! Decides when the face should go quiet for the night, and supplies the few
//! things it still shows.
//!
//! The face follows the state the WATCH is in, not the clock. Three sources,
//! tried in order:
//!
//!   1. ActivityMonitor.Info.isSleepMode, but only when it says TRUE. It is
//!      deprecated ("may be removed after System 4") and on the Enduro 3 it
//!      does not report sleep mode: night mode never came on in a real night's
//!      wear. A false from it is therefore not believed, only a true.
//!
//!   2. DeviceSettings.doNotDisturb. Garmin's sleep mode turns Do Not Disturb
//!      on (it is an option in the watch's sleep mode settings), so this is
//!      the watch's own sleep state as Connect IQ can still see it. Turning DND
//!      on by hand brings the night screen too, which is the price of using it.
//!
//!   3. The wearer's configured sleep window from UserProfile, only for a
//!      device that reports neither of the above. It is true between the
//!      configured times whether or not anyone is asleep, so a late evening
//!      inside the window looks like being in bed; that is why it was dropped
//!      as the main trigger and survives only as the last resort.
//!
//! Note for whoever edits this: reaching isSleepMode through Frame.monitor(), an
//! untyped accessor, is why the compiler does not print its deprecation warning
//! here. The deprecation is real — accessing it off a typed ActivityMonitor.Info
//! warns. Do not read the silence as approval.
//!
//! Connect IQ has NO API for the next alarm's TIME: DeviceSettings offers
//! alarmCount and nothing else. So the night face marks that an alarm is set
//! and says no more than that — a bell, drawn only when alarmCount > 0.
module NightMode {

    // The state is asked for on every draw and cannot change usefully within a
    // minute, so it is computed once per snapshot.
    var _active = false;
    var _minute = -1;

    function isActive() as Boolean {
        if (Frame.minute() != _minute) {
            _minute = Frame.minute();
            _active = compute();
        }
        return _active;
    }

    function compute() as Boolean {
        var info = Frame.monitor();
        var sleepMode = (info != null && (info has :isSleepMode)) ? info.isSleepMode : null;
        if (sleepMode == true) {
            return true;
        }
        var settings = Frame.settings;
        if (settings != null && (settings has :doNotDisturb)
                && settings.doNotDisturb != null) {
            return settings.doNotDisturb as Boolean;
        }
        if (sleepMode != null) {
            return false;
        }
        return inSleepWindow();
    }

    //! True while the clock sits inside the profile's sleep window. The window
    //! normally crosses midnight (22:30 -> 06:30), which is why this is not a
    //! plain range test: no instant is both after 22:30 and before 06:30.
    function inSleepWindow() as Boolean {
        var profile = Frame.profile();
        if (profile == null || !(profile has :sleepTime) || !(profile has :wakeTime)
                || profile.sleepTime == null || profile.wakeTime == null) {
            return false;
        }
        var sleep = (profile.sleepTime as Time.Duration).value();
        var wake = (profile.wakeTime as Time.Duration).value();
        if (sleep == wake) {
            return false;
        }
        var now = secondsSinceMidnight();
        if (sleep < wake) {
            return (now >= sleep) && (now < wake);
        }
        return (now >= sleep) || (now < wake);
    }

    function secondsSinceMidnight() as Number {
        var clock = Frame.clock;
        return clock.hour * 3600 + clock.min * 60 + clock.sec;
    }

    function alarmCount() as Number {
        var settings = Frame.settings;
        if (settings == null || !(settings has :alarmCount)
                || settings.alarmCount == null) {
            return 0;
        }
        return settings.alarmCount as Number;
    }
}

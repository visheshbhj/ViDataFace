import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;

//! Decides when the face should go quiet for the night, and supplies the few
//! things it still shows.
//!
//! Two triggers, either is enough:
//!   - the watch's own night mode setting (isNightModeEnabled), which the
//!     wearer controls directly, and
//!   - the sleep window from the user profile, so the face goes quiet on
//!     schedule even when night mode is not switched on.
//!
//! Connect IQ has NO API for the next alarm's time: DeviceSettings offers
//! alarmCount and nothing else. So the time shown is the profile's wake time —
//! the only upcoming wake-up the API will give us — and the alarm count sits
//! beside it when alarms are set.
module NightMode {

    const SECONDS_PER_DAY = 86400;

    function isActive() as Boolean {
        var settings = System.getDeviceSettings();
        if ((settings has :isNightModeEnabled) && settings.isNightModeEnabled) {
            return true;
        }
        return inSleepWindow();
    }

    //! True while the clock sits inside the profile's sleep window. The window
    //! normally crosses midnight (22:30 -> 06:30), which is why this is not a
    //! plain range test.
    function inSleepWindow() as Boolean {
        var profile = UserProfile.getProfile();
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
        var clock = System.getClockTime();
        return clock.hour * 3600 + clock.min * 60 + clock.sec;
    }

    //! The profile's wake time as "06:30", or null if it has none.
    function wakeText() as String? {
        var profile = UserProfile.getProfile();
        if (profile == null || !(profile has :wakeTime) || profile.wakeTime == null) {
            return null;
        }
        var secs = (profile.wakeTime as Time.Duration).value() % SECONDS_PER_DAY;
        return Lang.format("$1$:$2$",
            [(secs / 3600).format("%02d"), ((secs % 3600) / 60).format("%02d")]);
    }

    function alarmCount() as Number {
        var settings = System.getDeviceSettings();
        if (!(settings has :alarmCount) || settings.alarmCount == null) {
            return 0;
        }
        return settings.alarmCount as Number;
    }
}

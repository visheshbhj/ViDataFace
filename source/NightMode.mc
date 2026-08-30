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
//! Connect IQ has NO API for the next alarm's TIME: DeviceSettings offers
//! alarmCount and nothing else. So the night face marks that an alarm is set
//! and says no more than that — a bell, drawn only when alarmCount > 0.
module NightMode {

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

    function alarmCount() as Number {
        var settings = System.getDeviceSettings();
        if (!(settings has :alarmCount) || settings.alarmCount == null) {
            return 0;
        }
        return settings.alarmCount as Number;
    }
}

import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;

//! Decides when the face should go quiet for the night, and supplies the few
//! things it still shows.
//!
//! Two sources, tried in order:
//!
//!   1. ActivityMonitor.Info.isSleepMode — the state the watch itself is in,
//!      and the only one that knows whether sleep is actually ACTIVE rather
//!      than merely scheduled. It is DEPRECATED and typed "Boolean or Null",
//!      so it is used only when it actually answers.
//!
//!   2. The wearer's configured sleep window from UserProfile, for devices and
//!      firmware where the above returns null. This is a weaker signal: it is
//!      true between the configured times whether or not anyone is asleep, so
//!      a late evening inside the window looks like being in bed. Second place
//!      is the right place for it.
//!
//! Note for whoever edits this: reaching isSleepMode through Frame.monitor, an
//! untyped var, is why the compiler does not print its deprecation warning
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
        var info = Frame.monitor;
        if (info != null && (info has :isSleepMode) && info.isSleepMode != null) {
            return info.isSleepMode as Boolean;
        }
        return inSleepWindow();
    }

    //! True while the clock sits inside the profile's sleep window. The window
    //! normally crosses midnight (22:30 -> 06:30), which is why this is not a
    //! plain range test: no instant is both after 22:30 and before 06:30.
    function inSleepWindow() as Boolean {
        var profile = Frame.profile;
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

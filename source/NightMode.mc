import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;

//! Decides when the face should go quiet for the night, and supplies the few
//! things it still shows.
//!
//! The trigger is the watch's own sleep mode — ActivityMonitor.Info.isSleepMode
//! — and nothing else. That is the state the watch itself is in, whether it got
//! there on the wearer's sleep schedule or by being switched on by hand, so the
//! face follows the watch rather than second-guessing it.
//!
//! An earlier version also went quiet whenever the clock fell inside the sleep
//! window from UserProfile. That fired whether or not the wearer was actually
//! asleep — a late evening inside the window looked identical to being in bed —
//! and it cost the UserProfile permission at install. Both are gone.
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

    //! True only while the watch is in sleep mode. A device that does not report
    //! it never goes quiet, which is the right way to fail: a face that stays
    //! full is merely unhelpful at night, one stuck in night mode is useless by
    //! day.
    function compute() as Boolean {
        var info = Frame.monitor;
        if (info == null || !(info has :isSleepMode) || info.isSleepMode == null) {
            return false;
        }
        return info.isSleepMode as Boolean;
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

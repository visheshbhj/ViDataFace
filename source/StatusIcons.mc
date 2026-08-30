import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! The status row that sits in the band between the shoulder values and the
//! clock: phone, focus/do-not-disturb, alarm, notifications.
//!
//! Only active states are drawn, so a quiet watch shows an empty band rather
//! than a row of greyed-out icons. Each icon is loaded on first use and kept —
//! there are at most four, and which ones are showing changes rarely.
module StatusIcons {

    const RESOURCES = {
        :bluetooth => Rez.Drawables.StatusBluetooth,
        :dnd       => Rez.Drawables.StatusDnd,
        :alarm     => Rez.Drawables.StatusAlarm,
        :notify    => Rez.Drawables.StatusNotify
    };

    var _cache = {};

    function get(key) {
        var bitmap = _cache[key];
        if (bitmap == null) {
            bitmap = WatchUi.loadResource(RESOURCES[key]);
            _cache[key] = bitmap;
        }
        return bitmap;
    }

    //! Bitmaps for everything currently active, in a fixed order so icons do
    //! not swap places as states come and go.
    function active() as Array {
        var s = System.getDeviceSettings();
        var out = [] as Array;
        if ((s has :phoneConnected) && s.phoneConnected) {
            out.add(get(:bluetooth));
        }
        if ((s has :doNotDisturb) && s.doNotDisturb) {
            out.add(get(:dnd));
        }
        if ((s has :alarmCount) && s.alarmCount != null && s.alarmCount > 0) {
            out.add(get(:alarm));
        }
        if ((s has :notificationCount) && s.notificationCount != null
                && s.notificationCount > 0) {
            out.add(get(:notify));
        }
        return out;
    }

    //! Drop the cached bitmaps. Call from onHide() when memory is tight.
    function release() as Void {
        _cache = {};
    }
}

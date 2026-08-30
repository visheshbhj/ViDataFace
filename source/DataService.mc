import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Reads every value the watch face displays. Numbers come back RAW — the API's
//! own Float, in the API's own unit — because Layout owns formatting; see the
//! formatter block there. Only the clock fields, which have no numeric form,
//! return strings. null means the sensor, permission or sample is unavailable.
module DataService {

    //! Raw reading for a field, keyed by its layout id. Numeric for the sensor
    //! fields, String for the clock, null when there is nothing to show.
    function rawFor(name as String) as Object? {
        if (name.equals("TimeLabel"))        { return localTime(); }
        if (name.equals("AltitudeLabel"))    { return altitude(); }
        if (name.equals("BarometerLabel"))   { return pressure(); }
        if (name.equals("WeatherLabel"))     { return temperature(); }
        if (name.equals("StepsLabel"))       { return steps(); }
        if (name.equals("HeartRateLabel"))   { return heartRate(); }
        if (name.equals("CaloriesLabel"))    { return calories(); }
        if (name.equals("SolarLabel"))       { return solarIntensity(); }
        if (name.equals("BatteryLabel"))     { return batteryPercent(); }
        if (name.equals("StressLabel"))      { return stress(); }
        if (name.equals("BodyBatteryLabel")) { return bodyBattery(); }
        return null;
    }

    //! The clock digits, in whichever convention the watch is set to. The
    //! device setting decides; nothing here overrides it.
    function localTime() as String {
        var clock = System.getClockTime();
        var minutes = clock.min.format("%02d");

        if (!System.getDeviceSettings().is24Hour) {
            // 12-hour: midnight and noon are both "12", not "0". The old code
            // only subtracted when hour > 12, so 00:50 came out as "0:50".
            var hours = clock.hour % 12;
            if (hours == 0) {
                hours = 12;
            }
            return Lang.format("$1$:$2$", [hours, minutes]);
        }
        if (Application.Properties.getValue("UseMilitaryFormat")) {
            return Lang.format("$1$$2$", [clock.hour.format("%02d"), minutes]);
        }
        return Lang.format("$1$:$2$", [clock.hour.format("%02d"), minutes]);
    }

    //! "AM"/"PM" while the watch is on a 12-hour clock, null on a 24-hour one
    //! where the hour already says which half of the day it is.
    function meridiem() as String? {
        if (System.getDeviceSettings().is24Hour) {
            return null;
        }
        return (System.getClockTime().hour < 12) ? "AM" : "PM";
    }

    // FORMAT_MEDIUM gives abbreviated, already-localised names ("Fri", "Aug").
    // Only used when the device has no weekday complication to offer.
    function dateText() as String {
        var now = Time.Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$ $2$", [now.day_of_week, now.day.format("%02d")]);
    }

    //! Metres. Format with Layout.altitude().
    function altitude() as Numeric? {
        var info = Activity.getActivityInfo();
        if (info == null || !(info has :altitude) || info.altitude == null) {
            return null;
        }
        return info.altitude as Float;
    }

    //! PASCALS, not hectopascals — Layout.pressure() does the divide.
    function pressure() as Numeric? {
        var info = Activity.getActivityInfo();
        if (info == null || !(info has :ambientPressure) || info.ambientPressure == null) {
            return null;
        }
        return info.ambientPressure as Float;
    }

    //! Degrees C. Format with Layout.temp().
    function temperature() as Numeric? {
        if (!(Toybox has :Weather)) {
            return null;
        }
        var conditions = Toybox.Weather.getCurrentConditions();
        if (conditions == null || conditions.temperature == null) {
            return null;
        }
        return conditions.temperature as Number;
    }

    //! The raw Toybox.Weather.CONDITION_* value, or null when weather is
    //! unavailable. Kept unmapped: WeatherIcons indexes its art by this number.
    function weatherCondition() as Number? {
        if (!(Toybox has :Weather)) {
            return null;
        }
        var conditions = Toybox.Weather.getCurrentConditions();
        if (conditions == null || conditions.condition == null) {
            return null;
        }
        return conditions.condition as Number;
    }

    //! Battery charge 0..100, for the rim arc.
    function batteryPercent() as Number {
        return System.getSystemStats().battery.toNumber();
    }

    function steps() as Numeric? {
        var info = ActivityMonitor.getInfo();
        return (info.steps != null) ? info.steps as Number : null;
    }

    function heartRate() as Numeric? {
        var info = Activity.getActivityInfo();
        if (info == null || !(info has :currentHeartRate) || info.currentHeartRate == null) {
            return null;
        }
        return info.currentHeartRate as Number;
    }

    function calories() as Numeric? {
        var info = ActivityMonitor.getInfo();
        return (info.calories != null) ? info.calories as Number : null;
    }

    function solarIntensity() as Numeric? {
        var stats = System.getSystemStats();
        if (!(stats has :solarIntensity) || stats.solarIntensity == null) {
            return null;
        }
        return stats.solarIntensity as Number;
    }

    function stress() as Numeric? {
        var info = ActivityMonitor.getInfo();
        if (!(info has :stressScore) || info.stressScore == null) {
            return null;
        }
        return info.stressScore as Number;
    }

    function bodyBattery() as Numeric? {
        if (!(Toybox has :SensorHistory) || !(Toybox.SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }
        var sample = Toybox.SensorHistory.getBodyBatteryHistory({}).next();
        if (sample == null || sample.data == null) {
            return null;
        }
        return sample.data as Float;
    }
}

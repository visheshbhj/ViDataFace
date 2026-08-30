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

    // TEMPORARY — fixed worst-case values for eyeballing the layout at full
    // width. Set DEMO to false, or delete this block and the call in
    // ViDataFaceView.raw(), to go back to live sensors.
    const DEMO = true;
    function demoValue(name as String) as Object? {
        if (!DEMO) { return null; }
        if (name.equals("AltitudeLabel")) { return 11542.0; }   // 5 digits
        if (name.equals("StepsLabel"))    { return 88888; }     // 5 digits
        if (name.equals("CaloriesLabel")) { return 8888; }      // 4 digits
        return null;
    }

    //! Raw reading for a field, keyed by its layout id. Numeric for the sensor
    //! fields, String for the clock, null when there is nothing to show.
    function rawFor(name as String) as Object? {
        if (name.equals("TimeLabel"))        { return localTime(); }
        if (name.equals("ISTTimeLabel"))     { return istTime(); }
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

    function localTime() as String {
        var timeFormat = "$1$:$2$";
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        } else {
            if (Application.Properties.getValue("UseMilitaryFormat")) {
                timeFormat = "$1$$2$";
                hours = hours.format("%02d");
            }
        }
        return Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);
    }

    // IST is UTC+05:30 and observes no DST, so a fixed offset is exact.
    function istTime() as String {
        var ist = Time.Gregorian.utcInfo(Time.now().add(new Time.Duration(19800)),
            Time.FORMAT_SHORT);
        return Lang.format("$1$:$2$", [ist.hour.format("%02d"), ist.min.format("%02d")]);
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

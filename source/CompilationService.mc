import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;

//! Subscribes to every complication that backs a field on the face and caches
//! the latest value for each. Garmin pushes updates through a single callback,
//! so nothing here polls.
//!
//! draw() prints the whole cache on screen as a diagnostic list: it is a way to
//! see what each complication actually reports on the device, not a face layout.
class CompilationService {

    // Field name (see DataService) -> the complication that supplies it.
    // TimeLabel and ISTTimeLabel are computed from the clock, not complications.
    private const SUBSCRIPTIONS as Dictionary<String, Complications.Type> = {
        "DateLabel"        => Complications.COMPLICATION_TYPE_WEEKDAY_MONTHDAY,
        "AltitudeLabel"    => Complications.COMPLICATION_TYPE_ALTITUDE,
        "BarometerLabel"   => Complications.COMPLICATION_TYPE_SEA_LEVEL_PRESSURE,
        "WeatherLabel"     => Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE,
        "StepsLabel"       => Complications.COMPLICATION_TYPE_STEPS,
        "HeartRateLabel"   => Complications.COMPLICATION_TYPE_HEART_RATE,
        "CaloriesLabel"    => Complications.COMPLICATION_TYPE_CALORIES,
        "SolarLabel"       => Complications.COMPLICATION_TYPE_SOLAR_INPUT,
        "BatteryLabel"     => Complications.COMPLICATION_TYPE_BATTERY,
        "StressLabel"      => Complications.COMPLICATION_TYPE_STRESS,
        "BodyBatteryLabel" => Complications.COMPLICATION_TYPE_BODY_BATTERY
    };

    private const NO_VALUE as String = "--";

    // Field name -> last value pushed for it, RAW: whatever type the
    // complication reports, usually Float. Formatting is Layout's job, so
    // nothing here stringifies a reading.
    private var _values as Dictionary<String, Object> = {};
    // Field name -> whether subscribeToUpdates() was accepted by the device.
    private var _subscribed as Dictionary<String, Boolean> = {};
    private var _started as Boolean = false;

    function initialize() {
    }

    //! Register for updates. Call from onShow(); pair with stop().
    function start() as Void {
        if (_started || !(Toybox has :Complications)) {
            return;
        }
        _started = true;

        // Must be a non-private method: method() resolves it by symbol.
        Complications.registerComplicationChangeCallback(method(:onComplicationChanged));

        var names = SUBSCRIPTIONS.keys();
        for (var i = 0; i < names.size(); i++) {
            var name = names[i];
            var type = SUBSCRIPTIONS.get(name);
            if (type == null) {
                continue;
            }
            var id = new Complications.Id(type as Complications.Type);
            // A device that doesn't support the complication returns false here
            // rather than throwing, so a failed subscribe is data, not an error.
            _subscribed.put(name, Complications.subscribeToUpdates(id));
            // Seed the cache: subscribing only delivers *changes*, so without a
            // first read every field stays blank until its next update.
            cache(name, readValue(id));
        }
    }

    //! Drop every subscription. Call from onHide().
    function stop() as Void {
        if (!_started) {
            return;
        }
        _started = false;
        Complications.unsubscribeFromAllUpdates();
        Complications.registerComplicationChangeCallback(null);
    }

    //! Must NOT be private: registered by symbol with the Complications module.
    function onComplicationChanged(id as Complications.Id) as Void {
        var name = nameForType(id.getType());
        if (name == null) {
            return;
        }
        cache(name as String, readValue(id));
    }

    // Only real readings are cached, so hasValue() stays honest: an unsupported
    // or unconfigured complication leaves no entry rather than storing "--".
    private function cache(name as String, value as Object?) as Void {
        if (value == null) {
            _values.remove(name);
            return;
        }
        _values.put(name, value as Object);
    }

    //! True when this field has a real complication reading to show.
    function hasValue(name as String) as Boolean {
        return _values.hasKey(name);
    }

    //! Latest reading for a field as a number, or null when there is none to
    //! show. Non-numeric complications (the weekday, say) return null too: the
    //! caller wants something Layout can format.
    function getNumber(name as String) as Numeric? {
        var value = _values.get(name);
        if (value instanceof Lang.Number || value instanceof Lang.Float ||
            value instanceof Lang.Long || value instanceof Lang.Double) {
            return value as Numeric;
        }
        return null;
    }

    //! The reading as text, for the fields that are words rather than numbers
    //! — the weekday and monthday, which arrive already localised by the
    //! device. Returns null when there is nothing cached.
    function getText(name as String) as String? {
        var value = _values.get(name);
        if (value == null) {
            return null;
        }
        return value.toString();
    }

    //! The raw reading rendered for the diagnostic list, or "--". Display code
    //! should use getNumber() and a Layout formatter instead.
    function getValue(name as String) as String {
        var value = _values.get(name);
        return (value != null) ? value.toString() : NO_VALUE;
    }

    function isSubscribed(name as String) as Boolean {
        var ok = _subscribed.get(name);
        return (ok != null) ? ok as Boolean : false;
    }

    private function nameForType(type as Complications.Type) as String? {
        var names = SUBSCRIPTIONS.keys();
        for (var i = 0; i < names.size(); i++) {
            if (SUBSCRIPTIONS.get(names[i]) == type) {
                return names[i];
            }
        }
        return null;
    }

    //! null when the complication has no reading to give: either it isn't
    //! configured on this device, or it hasn't reported yet.
    private function readValue(id as Complications.Id) as Object? {
        try {
            var complication = Complications.getComplication(id);
            // The unit is deliberately dropped: Layout decides which fields
            // carry a suffix, so that "838" cannot arrive pre-labelled "838 hPa"
            // from one path and bare from the other.
            return complication.value;
        } catch (e instanceof Complications.ComplicationNotFoundException) {
            return null;
        }
    }

    //! Diagnostic print: one row per subscription, "name  value", over a cleared
    //! screen. A leading "x" means the device rejected the subscription, "?"
    //! means it was accepted but no reading has arrived.
    function draw(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var font = Graphics.FONT_XTINY;
        var lineH = Graphics.getFontHeight(font);
        var names = SUBSCRIPTIONS.keys();
        // Centre the block vertically so it stays inside the round bezel.
        var y = dc.getHeight() / 2 - (names.size() * lineH) / 2;
        var cx = dc.getWidth() / 2;

        for (var i = 0; i < names.size(); i++) {
            var name = names[i] as String;
            var mark = !isSubscribed(name) ? "x " : (!hasValue(name) ? "? " : "");
            // Trim the shared "Label" suffix: these rows are tight for width.
            var shortName = name.substring(0, name.length() - 5);
            dc.drawText(cx, y + i * lineH, font,
                mark + shortName + " " + getValue(name),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

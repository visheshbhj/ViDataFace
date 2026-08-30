import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Draws the Pass 6a face. Every position, colour, font and format lives in
//! Layout; this class only decides which reading goes in which slot, and which
//! Layout formatter turns it into text. Nothing here formats a number itself.
class ViDataFaceView extends WatchUi.WatchFace {

    private var _complications as CompilationService = new CompilationService();
    // Tracked so the complication subscriptions are torn down once on the way
    // into night mode, not re-evaluated on every draw.
    private var _night as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        _night = NightMode.isActive();
        if (!_night) {
            _complications.start();
        }
    }

    //! Night mode exists to stop work, not just to draw less: the complication
    //! subscriptions are dropped on the way in and taken out again on the way
    //! out, so nothing is being pushed to a face that would not draw it.
    private function updateNight() as Void {
        var night = NightMode.isActive();
        if (night == _night) {
            return;
        }
        _night = night;
        if (night) {
            _complications.stop();
        } else {
            _complications.start();
        }
    }

    //! The clock, the second timezone, and the next wake-up. Nothing else: no
    //! sensors are read and no battery arc is drawn.
    private function drawNight(dc as Dc) as Void {
        var wake = NightMode.wakeText();
        if (wake != null) {
            // The bell is always shown: a bare "08:00" beside a clock reading
            // 03:12 does not say what it is. It marks the row as the wake-up,
            // whether or not a separate alarm is also set.
            Layout.putIconText(dc, :night_alarm, StatusIcons.get(:alarm), wake);
        }
        Layout.put(dc, :night_clock, DataService.localTime());
        Layout.put(dc, :night_zone,  SecondZone.text());
    }

    //! The raw reading for a field, complication first: where the device offers
    //! one it is the better sensor path. Both paths hand back the API's own
    //! number in the API's own unit, so the Layout formatter downstream is the
    //! same either way.
    private function raw(name as String) as Object? {
        var value = _complications.getNumber(name);
        if (value != null) {
            return value;
        }
        return DataService.rawFor(name);
    }

    private function drawFields(dc as Dc) as Void {
        Layout.battery(dc, DataService.batteryPercent());

        // Nothing is drawn when the sky is unknown: an empty slot reads better
        // than a placeholder next to a live temperature.
        Layout.putBitmap(dc, :weather_icon,
            WeatherIcons.get(DataService.weatherCondition()));

        Layout.putBitmapRow(dc, :status_row, StatusIcons.active());

        // The clock fields are the only ones that are already text.
        Layout.put(dc, :clock,      DataService.localTime());
        Layout.put(dc, :timezone_2, SecondZone.text());

        Layout.put(dc, :temperature,  Layout.temp(raw("WeatherLabel")));

        // Altitude is signed by a leading triangle rather than a minus sign;
        // the barometer trails the 4-hour trend chevron.
        var alt = raw("AltitudeLabel");
        Layout.putMarked(dc, :altitude, Layout.altitude(alt), Layout.altitudeMark(alt), null);
        Layout.putMarked(dc, :barometer, Layout.pressure(raw("BarometerLabel")),
            null, Trend.marker());

        Layout.put(dc, :cal_value,    Layout.num(raw("CaloriesLabel")));
        Layout.put(dc, :hr_value,     Layout.num(raw("HeartRateLabel")));
        Layout.put(dc, :steps_value,  Layout.num(raw("StepsLabel")));

        Layout.put(dc, :body_value,   Layout.pct(raw("BodyBatteryLabel")));
        Layout.put(dc, :solar_value,  Layout.pct(raw("SolarLabel")));
        Layout.put(dc, :stress_value, Layout.pct(raw("StressLabel")));

        var captions = Layout.LABELS.keys();
        for (var i = 0; i < captions.size(); i++) {
            Layout.label(dc, captions[i]);
        }
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate first to redraw the layout: Background.draw()
        // calls dc.clear(), which would erase anything drawn before it.
        View.onUpdate(dc);

        updateNight();
        if (_night) {
            drawNight(dc);
            return;
        }
        drawFields(dc);
        // Diagnostic page: clears the screen and lists every complication.
        //_complications.draw(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        _complications.stop();
        WeatherIcons.release();
        StatusIcons.release();
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }

}

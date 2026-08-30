import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Draws the Pass 6a face. Every position, colour, font and format lives in
//! Layout; this class only decides which reading goes in which slot, and which
//! Layout formatter turns it into text. Nothing here formats a number itself.
class ViDataFaceView extends WatchUi.WatchFace {

    private var _complications as CompilationService = new CompilationService();

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
        _complications.start();
    }

    //! The raw reading for a field, complication first: where the device offers
    //! one it is the better sensor path. Both paths hand back the API's own
    //! number in the API's own unit, so the Layout formatter downstream is the
    //! same either way.
    private function raw(name as String) as Object? {
        var demo = DataService.demoValue(name);   // TEMPORARY, see DataService.DEMO
        if (demo != null) {
            return demo;
        }
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

        // The clock fields are the only ones that are already text.
        Layout.put(dc, :clock,      DataService.localTime());
        Layout.put(dc, :timezone_2, DataService.istTime());

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
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }

}

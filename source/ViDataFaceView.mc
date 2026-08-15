import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class ViDataFaceView extends WatchUi.WatchFace {

    private var _fontTimer as Timer.Timer?;
    private var _fontIndex as Number = 0;

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
        _fontTimer = new Timer.Timer();
        _fontTimer.start(method(:onFontTimer), 10000, true);
    }

    private function onFontTimer() as Void {
        _fontIndex = (_fontIndex + 1) % ALL_FACE_NAMES.size();
        WatchUi.requestUpdate();
    }

    private const ALL_FACE_NAMES as Array<String> = [
        "BionicBold", "ExoSemiBold", "KosugiRegular", "NanumGothicBold", "NanumGothicExtraBold",
        "NanumGothicRegular", "NotoNaskhArabicBold", "NotoNaskhArabicRegular", "NotoSansArmenianBold",
        "NotoSansArmenianRegular", "NotoSansHebrewBold", "NotoSansHebrewRegular", "NotoSansSCMedium",
        "PridiRegular", "PridiRegularGarmin", "PridiSemiBoldGarmin", "RobotoBlack", "RobotoCondensedBold",
        "RobotoCondensedRegular", "RobotoCondensedRegularItalic", "RobotoRegular", "SakkalMajallaBold",
        "SakkalMajallaRoman", "Swiss721Bold", "Swiss721Regular", "TomorrowBold", "YantramanavRegular"
    ];

    private const FONT_TEST_TEXT as String = "▲▼▴▾ ⦵ ♥ 🜂 ⭍☼ ☀︽ ︾";

    private function drawFontSupportTest(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var labelFont = Graphics.getVectorFont({:face => "RobotoCondensedRegular", :size => 10});
        if (labelFont == null) {
            labelFont = Graphics.FONT_XTINY;
        }

        var name = ALL_FACE_NAMES[_fontIndex];
        var vf = Graphics.getVectorFont({:face => name, :size => 32});
        var status = (vf != null) ? "OK" : "--";

        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.drawText(width / 2, height / 2 - 40, labelFont, name + " " + status,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var testFont = (vf != null) ? vf : labelFont;
        dc.drawText(width / 2, height / 2, testFont, FONT_TEST_TEXT,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Get the current time and format it correctly
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
        var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);

        // Update the view
        var view = View.findDrawableById("TimeLabel") as Text;
        view.setColor(Application.Properties.getValue("ForegroundColor") as Number);
        view.setText(timeString);
        
        //drawFontSupportTest(dc);
        

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        if (_fontTimer != null) {
            _fontTimer.stop();
            _fontTimer = null;
        }
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }

}

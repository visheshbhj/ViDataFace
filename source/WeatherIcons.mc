import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! The weather condition art in resources/drawables/weather. File 07 is
//! CONDITION_WINTRY_MIX, file 20 is CONDITION_CLOUDY, and so on: the number in
//! every id is the Toybox.Weather.CONDITION_* value, so the enum indexes RESOURCES
//! straight off. That is why no condition is spelled out here.
//!
//! Only the icon currently on screen is resident. get() keeps the last one and
//! reloads only when the sky changes, so the face carries one 28x28 bitmap
//! rather than all 54.
module WeatherIcons {

    const RESOURCES = [
        Rez.Drawables.WeatherIcon00,
        Rez.Drawables.WeatherIcon01,
        Rez.Drawables.WeatherIcon02,
        Rez.Drawables.WeatherIcon03,
        Rez.Drawables.WeatherIcon04,
        Rez.Drawables.WeatherIcon05,
        Rez.Drawables.WeatherIcon06,
        Rez.Drawables.WeatherIcon07,
        Rez.Drawables.WeatherIcon08,
        Rez.Drawables.WeatherIcon09,
        Rez.Drawables.WeatherIcon10,
        Rez.Drawables.WeatherIcon11,
        Rez.Drawables.WeatherIcon12,
        Rez.Drawables.WeatherIcon13,
        Rez.Drawables.WeatherIcon14,
        Rez.Drawables.WeatherIcon15,
        Rez.Drawables.WeatherIcon16,
        Rez.Drawables.WeatherIcon17,
        Rez.Drawables.WeatherIcon18,
        Rez.Drawables.WeatherIcon19,
        Rez.Drawables.WeatherIcon20,
        Rez.Drawables.WeatherIcon21,
        Rez.Drawables.WeatherIcon22,
        Rez.Drawables.WeatherIcon23,
        Rez.Drawables.WeatherIcon24,
        Rez.Drawables.WeatherIcon25,
        Rez.Drawables.WeatherIcon26,
        Rez.Drawables.WeatherIcon27,
        Rez.Drawables.WeatherIcon28,
        Rez.Drawables.WeatherIcon29,
        Rez.Drawables.WeatherIcon30,
        Rez.Drawables.WeatherIcon31,
        Rez.Drawables.WeatherIcon32,
        Rez.Drawables.WeatherIcon33,
        Rez.Drawables.WeatherIcon34,
        Rez.Drawables.WeatherIcon35,
        Rez.Drawables.WeatherIcon36,
        Rez.Drawables.WeatherIcon37,
        Rez.Drawables.WeatherIcon38,
        Rez.Drawables.WeatherIcon39,
        Rez.Drawables.WeatherIcon40,
        Rez.Drawables.WeatherIcon41,
        Rez.Drawables.WeatherIcon42,
        Rez.Drawables.WeatherIcon43,
        Rez.Drawables.WeatherIcon44,
        Rez.Drawables.WeatherIcon45,
        Rez.Drawables.WeatherIcon46,
        Rez.Drawables.WeatherIcon47,
        Rez.Drawables.WeatherIcon48,
        Rez.Drawables.WeatherIcon49,
        Rez.Drawables.WeatherIcon50,
        Rez.Drawables.WeatherIcon51,
        Rez.Drawables.WeatherIcon52,
        Rez.Drawables.WeatherIcon53 
    ];

    // Condition of the cached bitmap, or -1 when nothing is loaded yet.
    var _condition = -1;
    var _bitmap = null;

    //! The icon for a Toybox.Weather.CONDITION_* value, or null if the value is
    //! outside the range we have art for.
    function get(condition) {
        if (condition == null || condition < 0 || condition >= RESOURCES.size()) {
            return null;
        }
        if (condition != _condition || _bitmap == null) {
            _bitmap = WatchUi.loadResource(RESOURCES[condition]);
            _condition = condition;
        }
        return _bitmap;
    }

    //! Drop the cached bitmap. Call from onHide() when memory is tight.
    function release() {
        _bitmap = null;
        _condition = -1;
    }
}

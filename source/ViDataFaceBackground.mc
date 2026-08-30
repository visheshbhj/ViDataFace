import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Background extends WatchUi.Drawable {

    function initialize() {
        var dictionary = {
            :identifier => "Background"
        };

        Drawable.initialize(dictionary);
    }

    function draw(dc as Dc) as Void {
        // The ground is part of the design, not a setting: every ink in Layout
        // is picked for contrast against it.
        dc.setColor(Graphics.COLOR_TRANSPARENT, Layout.BG);
        dc.clear();
    }

}

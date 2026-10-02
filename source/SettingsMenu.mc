import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! The on-watch settings menu, reached from the watch face's own customise
//! option. A sideloaded app gets no settings page in Garmin Connect, so this is
//! the only way to change them on the wrist; it writes the same properties the
//! Connect page would.
//!
//! Each numeric setting is a short list of values rather than a number picker:
//! two button presses to pick, and nothing to scroll through one at a time.
module SettingsMenu {

    // Property key -> the values offered. Ranges match Settings.load().
    const CHOICES = {
        "SecondZone"       => [0, 1, 2, 3, 4, 5, 6, 7, 8],
        "TrendRefreshMin"  => [5, 10, 15, 20, 30, 45, 60],
        "TrendWindowHours" => [1, 2, 3, 4, 5, 6],
        "BatteryLowPct"    => [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90]
    };

    // Zone names, in SecondZone.ZONES order.
    const ZONE_NAMES = [
        Rez.Strings.ZoneIST, Rez.Strings.ZoneUTC, Rez.Strings.ZoneLON,
        Rez.Strings.ZoneNYC, Rez.Strings.ZoneSFO, Rez.Strings.ZoneDXB,
        Rez.Strings.ZoneSIN, Rez.Strings.ZoneTYO, Rez.Strings.ZoneSYD
    ];

    function build() as Menu2 {
        var menu = new WatchUi.Menu2({ :title => "ViDataFace" });
        menu.addItem(choiceItem("SecondZone",       "Second zone"));
        menu.addItem(choiceItem("TrendRefreshMin",  "Trend refresh"));
        menu.addItem(choiceItem("TrendWindowHours", "Trend lookback"));
        menu.addItem(choiceItem("BatteryLowPct",    "Battery low at"));
        menu.addItem(new WatchUi.ToggleMenuItem("Military time", null,
            "UseMilitaryFormat", Application.Properties.getValue("UseMilitaryFormat") == true, null));
        return menu;
    }

    function choiceItem(key as String, title as String) as MenuItem {
        return new WatchUi.MenuItem(title, describe(key, current(key)), key, null);
    }

    //! The stored value, or the value Settings would fall back to.
    function current(key as String) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            return v;
        }
        if (key.equals("TrendRefreshMin"))  { return Settings.trendRefreshMin; }
        if (key.equals("TrendWindowHours")) { return Settings.trendWindowHours; }
        if (key.equals("BatteryLowPct"))    { return Settings.batteryLowPct; }
        return 0;
    }

    function describe(key as String, v as Number) as String {
        if (key.equals("SecondZone")) {
            return (v >= 0 && v < ZONE_NAMES.size())
                ? WatchUi.loadResource(ZONE_NAMES[v]) as String : "--";
        }
        if (key.equals("TrendRefreshMin"))  { return v.format("%d") + " min"; }
        if (key.equals("TrendWindowHours")) { return v.format("%d") + " h"; }
        return v.format("%d") + "%";
    }

    //! Store a value and make the face pick it up now, not at the next minute.
    //! Writing a property from inside the app does not call onSettingsChanged,
    //! so this does what it would.
    function apply(key as String, value) as Void {
        Application.Properties.setValue(key, value);
        Frame.invalidate();
        WatchUi.requestUpdate();
    }
}

//! The top-level menu: a toggle flips in place, anything else opens its list.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        var key = item.getId() as String;
        if (item instanceof WatchUi.ToggleMenuItem) {
            SettingsMenu.apply(key, item.isEnabled());
            return;
        }

        var values = SettingsMenu.CHOICES[key] as Array<Number>;
        var now = SettingsMenu.current(key);
        var list = new WatchUi.Menu2({ :title => item.getLabel() });
        var focus = 0;
        for (var i = 0; i < values.size(); i++) {
            list.addItem(new WatchUi.MenuItem(
                SettingsMenu.describe(key, values[i]), null, values[i], null));
            if (values[i] == now) { focus = i; }
        }
        list.setFocus(focus);
        WatchUi.pushView(list, new SettingsChoiceDelegate(key, item), WatchUi.SLIDE_LEFT);
    }
}

//! One setting's list of values. Picking one stores it, updates the parent
//! row's sub-label to match, and goes back.
class SettingsChoiceDelegate extends WatchUi.Menu2InputDelegate {

    private var _key as String;
    private var _parent as MenuItem;

    function initialize(key as String, parent as MenuItem) {
        Menu2InputDelegate.initialize();
        _key = key;
        _parent = parent;
    }

    function onSelect(item as MenuItem) as Void {
        var value = item.getId() as Number;
        SettingsMenu.apply(_key, value);
        _parent.setSubLabel(SettingsMenu.describe(_key, value));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

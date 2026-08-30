import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Time;

//! The second timezone shown under the clock.
//!
//! Connect IQ exposes NO way to read the alternate time zones configured on the
//! watch: there is no such field on DeviceSettings, no complication type for
//! it, and the word "alternate" does not appear anywhere in the API. So the
//! zone is chosen in app settings instead, from the list below.
//!
//! Each zone is a LOCATION, not a fixed offset. Time.Gregorian.localMoment()
//! resolves the offset and the daylight saving rules for that place at that
//! instant, so London and New York follow their own DST changes without any
//! date arithmetic here. The previous code added a hard 19800 seconds, which is
//! right for India — the one zone where it cannot be wrong — and silently wrong
//! for half the year anywhere that observes DST.
module SecondZone {

    const ZONES = [
        { :label => "IST", :lat =>  28.6139, :lon =>  77.2090 },   // Delhi
        { :label => "UTC", :label_only => true, :lat => 51.4779, :lon => -0.0015 },
        { :label => "LON", :lat =>  51.5074, :lon =>  -0.1278 },
        { :label => "NYC", :lat =>  40.7128, :lon => -74.0060 },
        { :label => "SFO", :lat =>  37.7749, :lon =>-122.4194 },
        { :label => "DXB", :lat =>  25.2048, :lon =>  55.2708 },
        { :label => "SIN", :lat =>   1.3521, :lon => 103.8198 },
        { :label => "TYO", :lat =>  35.6762, :lon => 139.6503 },
        { :label => "SYD", :lat => -33.8688, :lon => 151.2093 }
    ];

    //! "IST 23:57" — the label makes the row self-describing once the zone is
    //! configurable. Falls back to plain local-offset arithmetic on a device
    //! without localMoment().
    function text() as String {
        var zone = ZONES[index()];
        var label = zone[:label] as String;
        return label + " " + clock(zone);
    }

    function index() as Number {
        var stored = Application.Properties.getValue("SecondZone");
        if (stored == null) {
            return 0;
        }
        var i = stored.toNumber();
        if (i == null || i < 0 || i >= ZONES.size()) {
            return 0;
        }
        return i;
    }

    function clock(zone) as String {
        var now = Time.now();
        if (Time.Gregorian has :localMoment) {
            var here = new Position.Location({
                :latitude  => zone[:lat],
                :longitude => zone[:lon],
                :format    => :degrees
            });
            var moment = Time.Gregorian.localMoment(here, now);
            if (moment != null) {
                var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
                return Lang.format("$1$:$2$",
                    [info.hour.format("%02d"), info.min.format("%02d")]);
            }
        }
        return "--:--";
    }
}

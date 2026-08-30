using Toybox.Graphics as Gfx;

// Enduro 3 watch face — Pass 6a layout map
// 280 x 280 MIP. Every entry is the anchor point used by drawText().
// :j is the Graphics justification flag for that anchor.
module Layout {

    const W = 280;
    const H = 280;
    const CX = 140;
    const CY = 140;

    // ---- ink ----------------------------------------------------------
    const INK_BRIGHT = 0xF2F4F0;  // primary values
    const INK_WHITE  = 0xFFFFFF;  // clock only
    const INK_DIM    = 0x78877D;  // labels
    const INK_MID    = 0x9AA79F;  // second timezone
    const INK_HR     = 0xFF4A33;  // heart rate
    const INK_SOLAR  = 0xFFAA00;  // solar value
    const INK_SOLARL = 0xA98B45;  // solar label
    const INK_TRACK  = 0x2A2F2A;  // battery arc track
    const BG         = 0x080A08;  // ground; every ink above is picked against it

    // ---- battery arc ---------------------------------------------------
    // Drawn with dc.setPenWidth(5); radius measured to the stroke centre.
    const ARC_R          = 132;
    const ARC_PEN        = 5;
    const ARC_START_DEG  = 90;    // 12 o'clock, sweeping clockwise
    const ARC_SWEEP_FULL = 360;

    // ---- font slots ----------------------------------------------------
    // These are slot NAMES, not fonts. ANCHORS still reads :f => F_VALUE; what
    // that resolves to is decided at runtime by font(), below.
    const F_CLOCK    = :clock;
    const F_VALUE    = :value;
    const F_TEMP     = :temp;
    const F_TZ       = :tz;
    const F_LABEL    = :label;

    // The device carries the same typefaces Garmin's own faces use, as vector
    // fonts, so the design px are reachable exactly — no custom .fnt needed.
    // BionicSemiBold is the face behind the stock numberHot; RobotoCondensed is
    // the face behind xtiny..large.
    //
    // :size is the design pixel height from the spec. :stock is the nearest
    // built-in, used only where a device has no vector font support — it runs
    // wider than the design metrics, which is what the 74 px column pitch
    // absorbs.
    const FONTS = {
        :clock    => { :face => "BionicSemiBold",         :size => 64, :stock => Gfx.FONT_NUMBER_HOT },
        :temp     => { :face => "RobotoCondensedBold",    :size => 26, :stock => Gfx.FONT_MEDIUM     },
        :value    => { :face => "RobotoCondensedBold",    :size => 22, :stock => Gfx.FONT_MEDIUM     },
        :tz       => { :face => "RobotoCondensedRegular", :size => 16, :stock => Gfx.FONT_SMALL      },
        :label    => { :face => "RobotoCondensedBold",    :size => 13, :stock => Gfx.FONT_XTINY      }
    };

    // Resolved slot -> font. Built once on first draw: getVectorFont() needs a
    // running device, so this cannot be a const.
    var _fonts = null;

    //! The font for a slot, or null if the slot is unknown.
    function font(slot) {
        if (slot == null) { return null; }
        if (_fonts == null) { loadFonts(); }
        return _fonts[slot];
    }

    // A device without vector fonts, or one missing a face, falls back per slot
    // rather than all-or-nothing.
    function loadFonts() {
        _fonts = {};
        var hasVector = (Gfx has :getVectorFont);
        var slots = FONTS.keys();
        for (var i = 0; i < slots.size(); i++) {
            var slot = slots[i];
            var spec = FONTS[slot];
            var f = null;
            if (hasVector) {
                f = Gfx.getVectorFont({ :face => spec[:face], :size => spec[:size] });
            }
            _fonts[slot] = (f != null) ? f : spec[:stock];
        }
    }

    const JC = Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER;
    const JL = Gfx.TEXT_JUSTIFY_LEFT   | Gfx.TEXT_JUSTIFY_VCENTER;

    // ---- anchors -------------------------------------------------------
    // :x :y are the anchor point, :j the justification, :c the colour.
    //
    // The six data fields sit on ONE arc of radius 100 about the centre,
    // sweeping 8 o'clock -> bottom -> 4 o'clock at -80/-48/-16/+16/+48/+80
    // degrees. Two straight rows of three cannot work on a round face: the
    // outer row's side fields land in the corners, where the bezel cuts them
    // off. Following the curve instead puts BODY and STRESS in the gutters
    // beside the clock, which were empty.
    const ANCHORS = {

        // top cluster
        :weather_icon   => { :x => 112, :y =>  48, :j => JC, :c => INK_BRIGHT, :f => null       }, // 28x28 bitmap, centred
        :temperature    => { :x => 132, :y =>  48, :j => JL, :c => INK_BRIGHT, :f => F_TEMP     },

        // shoulder row — inset to 76/204 so a 5-digit altitude plus its sign
        // triangle, and a barometer carrying a decimal and a chevron, still
        // clear the bezel
        :altitude       => { :x =>  76, :y =>  83, :j => JC, :c => INK_BRIGHT, :f => F_VALUE    },
        :barometer      => { :x => 204, :y =>  83, :j => JC, :c => INK_BRIGHT, :f => F_VALUE    },

        // clock block — the clock is on the true centre
        :clock          => { :x => 140, :y => 140, :j => JC, :c => INK_WHITE,  :f => F_CLOCK    },
        :timezone_2     => { :x => 140, :y => 186, :j => JC, :c => INK_MID,    :f => F_TZ       },

        // the arc, read left to right: -80 deg
        :body_label     => { :x =>  42, :y => 142, :j => JC, :c => INK_DIM,    :f => F_LABEL    },
        :body_value     => { :x =>  42, :y => 167, :j => JC, :c => INK_BRIGHT, :f => F_VALUE    },
        // -48 deg
        :cal_label      => { :x =>  66, :y => 192, :j => JC, :c => INK_DIM,    :f => F_LABEL    },
        :cal_value      => { :x =>  66, :y => 217, :j => JC, :c => INK_BRIGHT, :f => F_VALUE    },
        // -16 deg
        :hr_label       => { :x => 112, :y => 221, :j => JC, :c => INK_DIM,    :f => F_LABEL    },
        :hr_value       => { :x => 112, :y => 246, :j => JC, :c => INK_HR,     :f => F_VALUE    },
        // +16 deg
        :steps_label    => { :x => 168, :y => 221, :j => JC, :c => INK_DIM,    :f => F_LABEL    },
        :steps_value    => { :x => 168, :y => 246, :j => JC, :c => INK_BRIGHT, :f => F_VALUE    },
        // +48 deg
        :solar_label    => { :x => 214, :y => 192, :j => JC, :c => INK_SOLARL, :f => F_LABEL    },
        :solar_value    => { :x => 214, :y => 217, :j => JC, :c => INK_SOLAR,  :f => F_VALUE    },
        // +80 deg
        :stress_label   => { :x => 238, :y => 142, :j => JC, :c => INK_DIM,    :f => F_LABEL    },
        :stress_value   => { :x => 238, :y => 167, :j => JC, :c => INK_BRIGHT, :f => F_VALUE    }
    };

    // Label strings — short forms that fit 74 px at stock XTINY.
    const LABELS = {
        :cal_label    => "CAL",
        :hr_label     => "HR",
        :steps_label  => "STEPS",
        :body_label   => "BODY",
        :solar_label  => "SOLAR",
        :stress_label => "STRESS"
    };

    // Draw one anchored field.
    //   Layout.put(dc, :hr_value, "132");
    function put(dc, key, text) {
        var a = ANCHORS[key];
        if (a == null || a[:f] == null) { return; }
        var f = font(a[:f]);
        if (f == null) { return; }
        dc.setColor(a[:c], Gfx.COLOR_TRANSPARENT);
        dc.drawText(a[:x], a[:y], f, text, a[:j]);
    }

    // Bitmap on an anchor. The anchor is the centre of the image, matching how
    // drawText treats a JC anchor, so art of any size stays on the same spot.
    //   Layout.putBitmap(dc, :weather_icon, icon);
    function putBitmap(dc, key, bitmap) {
        var a = ANCHORS[key];
        if (a == null || bitmap == null) { return; }
        dc.drawBitmap(a[:x] - (bitmap.getWidth() / 2),
                      a[:y] - (bitmap.getHeight() / 2), bitmap);
    }

    // ---- value formatting ---------------------------------------------
    // The emulator showed raw floats (5.765788, 24.0000, 838.00000) because
    // the Garmin APIs hand back Float, not Number. Never pass an API value
    // straight to put() — run it through one of these.

    // Integer, no decimal point. null-safe.
    function num(v) {
        if (v == null) { return "--"; }
        return (v.toNumber()).format("%d");
    }

    // Altitude in metres, MAGNITUDE ONLY — the leading triangle carries the
    // sign, so "-340m" would double up on it. Five digits is reachable from a
    // plane, so the field is sized for "11000m" plus its marker.
    function altitude(m) {
        if (m == null) { return "--"; }
        var v = m.toNumber();
        return ((v < 0) ? -v : v).format("%d") + "m";
    }

    // Which triangle goes in front of an altitude: :up at or above sea level,
    // :down below it, null when there is no reading to sign.
    function altitudeMark(m) {
        if (m == null) { return null; }
        return (m.toNumber() < 0) ? :down : :up;
    }

    // Barometer in hPa, one decimal. Ambient pressure arrives in PASCALS —
    // divide by 100. The tenth is worth showing: a whole hPa is a big move for
    // a barometer, so integers hide most of what the trend chevron reacts to.
    function pressure(pa) {
        if (pa == null) { return "--"; }
        return (pa / 100.0).format("%.1f");
    }

    // Temperature, whole degrees, keeps the minus sign.
    function temp(c) {
        if (c == null) { return "--"; }
        return (c.toNumber()).format("%d") + "\u00B0";
    }

    // Percent fields (body battery, stress, solar intensity).
    function pct(v) {
        if (v == null) { return "--"; }
        return (v.toNumber()).format("%d") + "%";
    }

    // ---- drawn markers -------------------------------------------------
    // NONE of the marker glyphs exist in the device fonts: the four chevrons
    // U+FE3D-FE40 are in no face at all, and the triangles U+25B2/U+25BC only
    // in the CJK and Thai faces, whose weight does not match RobotoCondensed.
    // So they are drawn. Sizes are relative to the value font.
    const MARK_W    = 11;   // marker cell width
    const MARK_GAP  = 3;    // space between marker and text
    const CHEV_H    = 5;    // one chevron's rise
    const CHEV_PEN  = 2;
    const TRI_W     = 9;
    const TRI_H     = 8;

    // A "^" (or "v") stroke. A rapid change stacks two, matching the doubled
    // chevrons in the spec (up = rapid, up = gradual).
    function chevron(dc, cx, cy, up, rapid, colour) {
        dc.setColor(colour, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(CHEV_PEN);
        var w = MARK_W / 2;
        var n = rapid ? 2 : 1;
        // Stacked pair straddles the centre; a single one sits on it.
        var top = cy - (rapid ? (CHEV_H + 1) : CHEV_H / 2);
        for (var i = 0; i < n; i++) {
            var oy = top + i * (CHEV_H + 2);
            var apex = up ? oy : oy + CHEV_H;
            var tail = up ? oy + CHEV_H : oy;
            dc.drawLine(cx - w, tail, cx, apex);
            dc.drawLine(cx, apex, cx + w, tail);
        }
    }

    // Solid triangle, for the sign of a signed value.
    function triangle(dc, cx, cy, up, colour) {
        dc.setColor(colour, Gfx.COLOR_TRANSPARENT);
        var w = TRI_W / 2;
        var h = TRI_H / 2;
        var pts = up ? [[cx, cy - h], [cx + w, cy + h], [cx - w, cy + h]]
                     : [[cx, cy + h], [cx + w, cy - h], [cx - w, cy - h]];
        dc.fillPolygon(pts);
    }

    // A value with a marker beside it, the pair centred on the anchor as one
    // group so the text does not shift when a marker appears or goes away.
    //   lead  : :up / :down / null      (triangle, drawn before the text)
    //   trail : :rapid_up / :up / :down / :rapid_down / null  (chevron, after)
    function putMarked(dc, key, text, lead, trail) {
        var a = ANCHORS[key];
        if (a == null || a[:f] == null) { return; }
        var f = font(a[:f]);
        if (f == null) { return; }

        var tw = dc.getTextWidthInPixels(text, f);
        var lw = (lead == null)  ? 0 : MARK_W + MARK_GAP;
        var rw = (trail == null) ? 0 : MARK_GAP + MARK_W;
        var left = a[:x] - (lw + tw + rw) / 2;

        if (lead != null) {
            triangle(dc, left + MARK_W / 2, a[:y], lead == :up, a[:c]);
        }
        dc.setColor(a[:c], Gfx.COLOR_TRANSPARENT);
        dc.drawText(left + lw, a[:y], f, text, JL);
        if (trail != null) {
            var up = (trail == :up) || (trail == :rapid_up);
            var rapid = (trail == :rapid_up) || (trail == :rapid_down);
            chevron(dc, left + lw + tw + MARK_GAP + MARK_W / 2, a[:y], up, rapid, a[:c]);
        }
    }

    // Draw a label by key using its short form.
    function label(dc, key) {
        var s = LABELS[key];
        if (s != null) { put(dc, key, s); }
    }

    // Battery arc. pct is 0..100.
    function battery(dc, pct) {
        dc.setPenWidth(ARC_PEN);
        dc.setColor(INK_TRACK, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(CX, CY, ARC_R);
        if (pct <= 0) { return; }
        var sweep = (ARC_SWEEP_FULL * pct) / 100;
        dc.setColor(INK_BRIGHT, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(CX, CY, ARC_R, Gfx.ARC_CLOCKWISE,
                   ARC_START_DEG, ARC_START_DEG - sweep);
    }
}

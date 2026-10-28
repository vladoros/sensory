import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

class Flipper {
    // Durations are wall-clock time, so a slow watch drops frames instead of playing in slow motion
    const NORMAL_MS = 180;
    const SPIN_MS = 160;

    var shown as String;
    var target as String;
    var next as String? = null;
    var progress as Float = 0.0f;
    private var _queue as Array<String> = [];
    private var _duration as Number = NORMAL_MS;
    private var _startedAt as Number = 0;

    function initialize(text as String) {
        shown = text;
        target = text;
    }

    function set(text as String, animate as Boolean) as Void {
        if (text.equals(target)) {
            return;
        }
        target = text;
        if (animate) {
            _duration = NORMAL_MS;
            _queue.add(text);
        } else {
            finish();
        }
    }

    function spin(text as String, flips as Number) as Void {
        target = text;
        _duration = SPIN_MS;
        _queue = [];
        for (var i = 0; i < flips; i++) {
            _queue.add(((Math.rand() & 0x7FFFFFFF) % 100).format("%02d"));
        }
        _queue.add(text);
    }

    function active() as Boolean {
        return next != null || _queue.size() > 0;
    }

    function finish() as Void {
        _queue = [];
        next = null;
        progress = 0.0f;
        shown = target;
    }

    function tick(now as Number) as Void {
        if (next == null) {
            if (_queue.size() == 0) {
                return;
            }
            next = _queue[0];
            _queue = _queue.slice(1, null);
            progress = 0.0f;
            _startedAt = now;
            return;
        }
        progress = (now - _startedAt).toFloat() / _duration;
        if (progress >= 1.0f) {
            shown = next as String;
            next = null;
            progress = 0.0f;
        }
    }
}

module Flip {
    const PERSPECTIVE = 0.06f;

    enum Part {
        WHOLE,
        TOP,
        BOTTOM
    }

    // Under the front flap's edge line show the two flaps stacked behind it: a thin band, then a thicker one
    function stackNear(h as Number) as Number {
        return h * 23 / 1000 + 1;
    }

    function stackFar(h as Number) as Number {
        return h * 34 / 1000 + 1;
    }

    // Tile geometry for a screen `w` pixels wide; the flap buffer and both draw paths must agree on it
    function tileW(w as Number) as Number {
        return w * 385 / 1000;
    }

    function tileH(w as Number) as Number {
        return w * 375 / 1000;
    }

    function tileGap(w as Number) as Number {
        return w * 20 / 1000;
    }

    function tileTop(w as Number) as Number {
        return w * 195 / 1000;
    }

    function bodyHeight(h as Number) as Number {
        return h - stackNear(h) - stackFar(h);
    }

    // `part` limits drawing to one half so a flap can be rendered on its own
    function drawTile(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                      text as String, theme as Theme, font, part as Part) as Void {
        var r = w * 55 / 1000;
        var body = bodyHeight(h);
        var mid = y + body / 2;
        var clipTop = part == BOTTOM ? mid : y;
        var clipBottom = part == TOP ? mid : y + h;
        if (part != WHOLE) {
            dc.setClip(x, clipTop, w, clipBottom - clipTop);
        }

        var edge = w / 90 + 1;
        if (part != TOP) {
            var inset = w / 120 + 1;
            dc.setColor(theme.stackFar, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + 2 * inset, mid, w - 4 * inset, y + h - mid, r);
            dc.setColor(theme.stackNear, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + inset, mid, w - 2 * inset, y + body + stackNear(h) - mid, r);
        }
        dc.setColor(theme.border, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, body, r);
        if (part != BOTTOM) {
            if (part == WHOLE) {
                dc.setClip(x, y, w, mid - y);
            }
            dc.setColor(theme.top, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + edge, y + edge, w - 2 * edge, body - 2 * edge, r - edge);
        }
        if (part != TOP) {
            if (part == WHOLE) {
                dc.setClip(x, mid, w, y + body - mid);
            }
            dc.setColor(theme.bottom, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + edge, y + edge, w - 2 * edge, body - 2 * edge, r - edge);
        }
        if (part == WHOLE) {
            dc.clearClip();
        }

        dc.setColor(theme.digit, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, mid, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(theme.hinge, Graphics.COLOR_TRANSPARENT);
        var hinge = body / 50 + 1;
        dc.fillRectangle(x, mid - hinge / 2, w, hinge);
        var tabW = w * 5 / 100;
        var tabH = body / 9;
        if (part != WHOLE) {
            // The tabs straddle the tile's edges, so a half tile's clip must grow to keep its half of each tab
            dc.setClip(x - tabW / 2, clipTop, w + tabW, clipBottom - clipTop);
        }
        for (var side = 0; side < 2; side++) {
            var tx = side == 0 ? x - tabW / 2 : x + w - tabW / 2;
            dc.setColor(theme.tab, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(tx, mid - tabH / 2, tabW, tabH, 2);
            dc.setColor(theme.tabEdge, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(tx, mid - tabH / 2, tabW, tabH, 2);
        }
        dc.clearClip();
    }

    function drawFlipping(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                          flipper as Flipper, theme as Theme, font, buffer as BufferedBitmapReference) as Void {
        var mid = y + bodyHeight(h) / 2;
        var next = flipper.next as String;
        var p = flipper.progress;
        var bitmap = buffer.get() as BufferedBitmap?;
        if (bitmap == null) {
            // The graphics pool can reclaim the buffer; show the tile unflipped for this frame
            drawTile(dc, x, y, w, h, flipper.shown, theme, font, WHOLE);
            return;
        }

        drawTile(dc, x, y, w, h, next, theme, font, TOP);
        drawTile(dc, x, y, w, h, flipper.shown, theme, font, BOTTOM);
        if (p < 0.5f) {
            drawFlap(dc, bitmap, x, mid, w, h, flipper.shown, TOP, 1.0f - 2.0f * p, theme, font);
        } else {
            drawFlap(dc, bitmap, x, mid, w, h, next, BOTTOM, 2.0f * p - 1.0f, theme, font);
        }
    }

    // A top flap folds up into the hinge, a bottom flap swings down out of it. As a flap turns toward
    // the viewer its free edge widens past the tile, which is what makes the fold read as 3D.
    function drawFlap(dc as Dc, bitmap as BufferedBitmap, x as Number, mid as Number, w as Number, h as Number,
                      text as String, part as Part, scale as Float, theme as Theme, font) as Void {
        var half = bodyHeight(h) / 2;
        var face = part == TOP ? theme.top : theme.bottom;
        var bdc = bitmap.getDc();
        // Black, so the rounded corners of the tile stay rounded instead of filling in as square flap corners
        bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        bdc.clear();
        drawTile(bdc, 0, part == TOP ? 0 : -half, w, h, text, theme, font, part);

        var s = scale < 0.03f ? 0.03f : scale;
        var spread = (w * PERSPECTIVE * Math.sqrt(1.0f - s * s)).toNumber();
        var freeY = (part == TOP ? mid - s * half : mid + s * half).toNumber();
        dc.setColor(face, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, mid], [x + w, mid], [x + w + spread, freeY], [x - spread, freeY]]);

        // The flap bitmap is taller than half a tile, so clip it to its own half or its spare rows show as a strip
        var top = part == TOP ? freeY : mid;
        dc.setClip(x - spread, top, w + 2 * spread, (part == TOP ? mid - freeY : freeY - mid) + 1);
        var transform = new Graphics.AffineTransform();
        transform.setMatrix([1.0f, 0.0f, x.toFloat(), 0.0f, s, part == TOP ? mid - s * half : mid.toFloat()]);
        dc.drawBitmap2(0, 0, bitmap, {:transform => transform});
        dc.clearClip();
    }
}

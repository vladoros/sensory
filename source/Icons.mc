import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

module Icons {
    function bluetooth(dc as Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        var a = s / 2;
        var pts = [[-a, -a], [a, a], [0, s], [0, -s], [a, -a], [-a, a]];
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < pts.size() - 1; i++) {
            dc.drawLine(cx + pts[i][0], cy + pts[i][1], cx + pts[i + 1][0], cy + pts[i + 1][1]);
        }
        dc.setPenWidth(1);
    }

    function battery(dc as Dc, x as Number, cy as Number, w as Number, h as Number, percent as Number) as Void {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, cy - h / 2, w, h, 3);
        dc.setPenWidth(1);
        dc.fillRectangle(x + w, cy - h / 6, 3, h / 3);
        dc.setColor(percent <= 20 ? 0xFF4A3D : 0x7BD43A, Graphics.COLOR_TRANSPARENT);
        var inner = (w - 6) * percent / 100;
        dc.fillRectangle(x + 3, cy - h / 2 + 3, inner, h - 6);
    }

    function triangle(dc as Dc, cx as Number, cy as Number, s as Number, up as Boolean, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var d = up ? -s : s;
        dc.fillPolygon([[cx - s, cy - d / 2], [cx + s, cy - d / 2], [cx, cy + d / 2]]);
    }

    function moon(dc as Dc, cx as Number, cy as Number, r as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(r * 55 / 100);
        dc.drawArc(cx, cy, r * 70 / 100, Graphics.ARC_COUNTER_CLOCKWISE, 70, 290);
        dc.setPenWidth(1);
    }

    function heart(dc as Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - s / 2, cy - s / 4, s / 2);
        dc.fillCircle(cx + s / 2, cy - s / 4, s / 2);
        dc.fillPolygon([[cx - s, cy - s / 8], [cx + s, cy - s / 8], [cx, cy + s]]);
    }

    function drop(dc as Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy + s / 3, s * 2 / 3);
        dc.fillPolygon([[cx - s * 58 / 100, cy + s / 6], [cx + s * 58 / 100, cy + s / 6], [cx, cy - s]]);
    }

    // Indexed by Weather group
    function weatherIcon(group as Number, isDay as Boolean) as ResourceId {
        return [
            isDay ? Rez.Drawables.WeatherClearDay : Rez.Drawables.WeatherClearNight,
            isDay ? Rez.Drawables.WeatherPartlyDay : Rez.Drawables.WeatherPartlyNight,
            Rez.Drawables.WeatherCloudy,
            Rez.Drawables.WeatherFog,
            Rez.Drawables.WeatherDrizzle,
            Rez.Drawables.WeatherRain,
            Rez.Drawables.WeatherSnow,
            Rez.Drawables.WeatherShowers,
            Rez.Drawables.WeatherThunder
        ][group] as ResourceId;
    }
}

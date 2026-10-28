import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.UserProfile;
import Toybox.WatchUi;

class SensoryView extends WatchUi.WatchFace {
    const SLEEP_TEXT = 0x8A8A8A;

    private var _digitFont;
    private var _cityFont;
    private var _condFont;
    private var _tempFont;
    private var _smallFont;
    private var _bigFont;
    private var _sunriseIcon;
    private var _sunsetIcon;
    private var _stepsIcon;
    private var _weatherIcon;
    private var _weatherIconId;
    private var _fontFamily as Number? = null;
    private var _left as Flipper = new Flipper("00");
    private var _right as Flipper = new Flipper("00");
    private var _buffer as BufferedBitmapReference? = null;
    private var _timer as Timer.Timer = new Timer.Timer();
    private var _timerRunning as Boolean = false;
    private var _awake as Boolean = true;
    private var _primed as Boolean = false;
    private var _frameSettings as Settings? = null;
    private var _frameWeather as Dictionary? = null;
    private var _frameWeatherSet as Boolean = false;
    private var _locationAt as Number = -60000;
    private var _revivedAt as Number = System.getTimer();

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _fontFamily = null;
        var w = dc.getWidth();
        _buffer = Graphics.createBufferedBitmap({:width => Flip.tileW(w), :height => Flip.tileH(w) / 2});
        Math.srand(System.getTimer());
        _sunriseIcon = WatchUi.loadResource(Rez.Drawables.SunriseIcon);
        _sunsetIcon = WatchUi.loadResource(Rez.Drawables.SunsetIcon);
        _stepsIcon = WatchUi.loadResource(Rez.Drawables.StepsIcon);
        _weatherIconId = null;
    }

    function onShow() as Void {
        spin();
    }

    // A wrist raise only flips tiles whose time changed while the screen was dim; the spin is for opening the face
    function onExitSleep() as Void {
        _awake = true;
        WatchUi.requestUpdate();
    }

    private function spin() as Void {
        var settings = new Settings();
        if (_awake && !settings.isPowerSaving()) {
            var texts = clockTexts(settings);
            _left.spin(texts[0], 3);
            _right.spin(texts[1], 4);
            startTimer();
        }
    }

    function onEnterSleep() as Void {
        _awake = false;
        stopTimer();
        _left.finish();
        _right.finish();
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        var now = System.getTimer();
        _left.tick(now);
        _right.tick(now);
        if (!_left.active() && !_right.active()) {
            stopTimer();
        }
        WatchUi.requestUpdate();
    }

    private function startTimer() as Void {
        if (!_timerRunning) {
            _timer.start(method(:onTick), 50, true);
            _timerRunning = true;
        }
    }

    private function stopTimer() as Void {
        if (_timerRunning) {
            _timer.stop();
            _timerRunning = false;
        }
    }

    private function clockTexts(settings as Settings) as Array<String> {
        var t = System.getClockTime();
        var hour = t.hour;
        if (!settings.is24Hour()) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        return [hour.format("%02d"), t.min.format("%02d")];
    }

    // Fonts are bundled bitmaps because watches ship different system fonts: the Venu 3 has no bold Roboto
    private function loadFonts(family as Number) as Void {
        _digitFont = null;
        _cityFont = null;
        _condFont = null;
        _tempFont = null;
        _smallFont = null;
        _bigFont = null;
        var ids = family == Settings.INTER
            ? [Rez.Fonts.InterDigits, Rez.Fonts.InterCity, Rez.Fonts.InterCond, Rez.Fonts.InterTemp, Rez.Fonts.InterSmall, Rez.Fonts.InterBig]
            : [Rez.Fonts.RobotoDigits, Rez.Fonts.RobotoCity, Rez.Fonts.RobotoCond, Rez.Fonts.RobotoTemp, Rez.Fonts.RobotoSmall, Rez.Fonts.RobotoBig];
        _digitFont = WatchUi.loadResource(ids[0]);
        _cityFont = WatchUi.loadResource(ids[1]);
        _condFont = WatchUi.loadResource(ids[2]);
        _tempFont = WatchUi.loadResource(ids[3]);
        _smallFont = WatchUi.loadResource(ids[4]);
        _bigFont = WatchUi.loadResource(ids[5]);
        _fontFamily = family;
    }

    // Garmin's own weather carries the phone's location, which is fresher than the watch's last GPS fix
    private function rememberLocation(settings as Settings) as Void {
        var now = System.getTimer();
        if (now - _locationAt < 60000 || (settings.locationMode == 1 && settings.cityName.length() > 0)) {
            return;
        }
        _locationAt = now;
        var conditions = Toybox.Weather.getCurrentConditions();
        var position = conditions != null ? conditions.observationLocationPosition : null;
        if (position == null) {
            var info = Position.getInfo();
            position = info.accuracy != Position.QUALITY_NOT_AVAILABLE ? info.position : null;
        }
        if (position == null) {
            return;
        }
        var degrees = position.toDegrees();
        var saved = Application.Storage.getValue("loc");
        if (saved instanceof Array && saved.size() == 2
            && (saved[0] as Double - degrees[0]).abs() < 0.01 && (saved[1] as Double - degrees[1]).abs() < 0.01) {
            return;
        }
        Application.Storage.setValue("loc", degrees);
        if (saved == null) {
            (Application.getApp() as SensoryApp).scheduleWeather(true);
        }
    }

    // While a flip runs, onUpdate fires every 50 ms: reuse what the first frame read instead of hitting Storage each time
    private function settingsForFrame() as Settings {
        if (_frameSettings == null || !_timerRunning) {
            _frameSettings = new Settings();
        }
        return _frameSettings as Settings;
    }

    private function weatherForFrame(settings as Settings) as Dictionary? {
        if (!_frameWeatherSet || !_timerRunning) {
            _frameWeather = Weather.current(settings);
            _frameWeatherSet = true;
        }
        return _frameWeather;
    }

    // A lost background run leaves no recurring event, so ask again whenever the weather has stayed stale
    private function reviveWeather(settings as Settings) as Void {
        var now = System.getTimer();
        if (settings.weatherEnabled && now - _revivedAt > 600000 && Weather.current(settings) == null) {
            _revivedAt = now;
            (Application.getApp() as SensoryApp).scheduleWeather(true);
        }
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var settings = settingsForFrame();
        if (_fontFamily != settings.fontFamily) {
            loadFonts(settings.fontFamily);
        }
        if (!_timerRunning) {
            rememberLocation(settings);
            reviveWeather(settings);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (!_awake) {
            drawSleep(dc, w, settings);
            return;
        }
        var texts = clockTexts(settings);
        var animate = _primed && !settings.isPowerSaving();
        _left.set(texts[0], animate);
        _right.set(texts[1], animate);
        _primed = true;
        if (_left.active() || _right.active()) {
            startTimer();
        }

        drawStatusBar(dc, w);
        drawTiles(dc, w, settings);
        if (settings.weatherEnabled) {
            drawWeather(dc, w, settings);
            drawDateRow(dc, w, settings);
        } else {
            drawBigDate(dc, w, settings);
        }
    }

    // Low-power AMOLED frame: dim dark tiles and dim text, nudged a little every minute against burn-in
    private function drawSleep(dc as Dc, w as Number, settings as Settings) as Void {
        var minute = System.getClockTime().min;
        var ox = ((minute * 7) % 9) - 4;
        var oy = ((minute * 5) % 9) - 4;
        var texts = clockTexts(settings);
        var tileW = Flip.tileW(w);
        var gap = Flip.tileGap(w);
        var theme = new Theme(Theme.SLEEP);
        for (var i = 0; i < 2; i++) {
            var x = (i == 0 ? w / 2 - gap / 2 - tileW : w / 2 + gap / 2) + ox;
            Flip.drawTile(dc, x, Flip.tileTop(w) + oy, tileW, Flip.tileH(w), texts[i], theme, _digitFont, Flip.WHOLE);
        }

        var data = settings.weatherEnabled ? weatherForFrame(settings) : null;
        dc.setColor(SLEEP_TEXT, Graphics.COLOR_TRANSPARENT);
        if (data != null) {
            dc.drawText(w * 12 / 100 + ox, w * 655 / 1000 + oy, _cityFont, fittedCity(w, settings, data),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(w * 86 / 100 + ox, w * 665 / 1000 + oy, _tempFont,
                Weather.temp(data["t"] as Number, settings.tempUnit == 1),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var date = Strings.date(settings.language, settings.dateFormat, Gregorian.info(Time.now(), Time.FORMAT_SHORT));
        dc.drawText(w / 2 + ox, w * 885 / 1000 + oy, _cityFont, date,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function fittedCity(w as Number, settings as Settings, data as Dictionary?) as String {
        var city = settings.cityLabel;
        if (city.length() == 0 && data != null && data["city"] instanceof String) {
            city = data["city"] as String;
        }
        var fitted = Graphics.fitTextToArea(city, _cityFont, w * 32 / 100, w * 8 / 100, true);
        return fitted != null ? fitted : city;
    }

    private function drawStatusBar(dc as Dc, w as Number) as Void {
        var y = w * 105 / 1000;
        var device = System.getDeviceSettings();
        var percent = System.getSystemStats().battery.toNumber();

        Icons.bluetooth(dc, w * 33 / 100, y, w * 25 / 1000, device.phoneConnected ? 0x9A9A9A : 0x3A3A3A);
        if (device.doNotDisturb) {
            Icons.moon(dc, w * 46 / 100, y, w * 25 / 1000, 0xB39DFF);
        }

        var batX = w * 64 / 100;
        Icons.battery(dc, batX, y, w * 7 / 100, w * 35 / 1000, percent);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(batX - w * 15 / 1000, y, _smallFont, percent + "%",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawTiles(dc as Dc, w as Number, settings as Settings) as Void {
        var theme = new Theme(settings.tileTheme == 1 ? Theme.DARK : Theme.LIGHT);
        var tileW = Flip.tileW(w);
        var gap = Flip.tileGap(w);
        var tileH = Flip.tileH(w);
        var top = Flip.tileTop(w);
        drawTile(dc, _left, w / 2 - gap / 2 - tileW, top, tileW, tileH, theme);
        drawTile(dc, _right, w / 2 + gap / 2, top, tileW, tileH, theme);
    }

    private function drawTile(dc as Dc, flipper as Flipper, x as Number, y as Number, w as Number, h as Number,
                              theme as Theme) as Void {
        if (flipper.next != null && _buffer != null) {
            Flip.drawFlipping(dc, x, y, w, h, flipper, theme, _digitFont, _buffer);
        } else {
            Flip.drawTile(dc, x, y, w, h, flipper.shown, theme, _digitFont, Flip.WHOLE);
        }
    }

    private function drawWeather(dc as Dc, w as Number, settings as Settings) as Void {
        var data = weatherForFrame(settings);
        var left = w * 12 / 100;
        var right = w * 86 / 100;

        var condition = "";
        var temp = "--\u00B0";
        if (data != null) {
            var group = Weather.group(data["c"] as Number);
            drawWeatherIcon(dc, w * 53 / 100, w * 580 / 1000, Icons.weatherIcon(group, (data["d"] as Number) == 1));
            condition = Strings.CONDITIONS[settings.language][group];
            temp = Weather.temp(data["t"] as Number, settings.tempUnit == 1);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, w * 655 / 1000, _cityFont, fittedCity(w, settings, data),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x9A9A9A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, w * 725 / 1000, _condFont, condition,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(right, w * 665 / 1000, _tempFont, temp,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (data != null) {
            drawUnderTemp(dc, w, right, w * 765 / 1000, data, settings);
        }
    }

    private function drawWeatherIcon(dc as Dc, cx as Number, cy as Number, id as ResourceId) as Void {
        if (_weatherIconId != id) {
            _weatherIcon = WatchUi.loadResource(id);
            _weatherIconId = id;
        }
        var icon = _weatherIcon as BitmapResource;
        dc.drawBitmap(cx - icon.getWidth() / 2, cy - icon.getHeight() / 2, icon);
    }

    // Each item is [icon, color, text]; the icon is :up, :down, :drop, a bitmap, or null
    private function drawUnderTemp(dc as Dc, w as Number, right as Number, y as Number,
                                   data as Dictionary, settings as Settings) as Void {
        var f = settings.tempUnit == 1;
        var items;
        switch (settings.fieldWeather) {
            case 1:
                var is24 = settings.is24Hour();
                items = [
                    [_sunriseIcon, 0, Weather.clock(data["sr"] as Number?, is24)],
                    [_sunsetIcon, 0, Weather.clock(data["ss"] as Number?, is24)]
                ];
                break;
            case 2:
                items = [[:drop, 0x5BA8FF, (data["p"] as Number) + "%"]];
                break;
            case 3:
                items = [[null, 0, Weather.wind(data["wd"] as Number, f)]];
                break;
            default:
                items = [
                    [:up, 0xFF5A4F, Weather.temp(data["hi"] as Number, f)],
                    [:down, 0x5BA8FF, Weather.temp(data["lo"] as Number, f)]
                ];
        }

        var x = right;
        var near = w * 10 / 1000;
        var apart = w * 30 / 1000;
        var tri = w * 12 / 1000;
        for (var i = items.size() - 1; i >= 0; i--) {
            var icon = items[i][0];
            var color = items[i][1] as Number;
            var text = items[i][2] as String;
            dc.setColor(0x9A9A9A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, _smallFont, text, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            x -= dc.getTextWidthInPixels(text, _smallFont) + near;
            if (icon == :up || icon == :down) {
                Icons.triangle(dc, x - tri, y, tri, icon == :up, color);
                x -= 2 * tri;
            } else if (icon == :drop) {
                Icons.drop(dc, x - tri, y, tri, color);
                x -= 2 * tri;
            } else if (icon != null) {
                var bitmap = icon as BitmapResource;
                dc.drawBitmap(x - bitmap.getWidth(), y - bitmap.getHeight() / 2, bitmap);
                x -= bitmap.getWidth();
            }
            x -= apart;
        }
    }

    private function drawDateRow(dc as Dc, w as Number, settings as Settings) as Void {
        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w * 14 / 100, w * 82 / 100, w * 86 / 100, w * 82 / 100);
        var date = Strings.date(settings.language, settings.dateFormat, Gregorian.info(Time.now(), Time.FORMAT_SHORT));
        drawMetricRow(dc, w, w * 885 / 1000, date, settings);
    }

    // With weather off, the weekday and the long date take the weather's place
    private function drawBigDate(dc as Dc, w as Number, settings as Settings) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, w * 680 / 1000, _bigFont, Strings.WEEKDAYS_FULL[settings.language][info.day_of_week - 1],
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x9A9A9A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, w * 765 / 1000, _condFont, Strings.longDate(settings.language, settings.dateFormat, info),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawMetricRow(dc, w, w * 860 / 1000, null, settings);
    }

    // One centered line: "date · icon value", or just "icon value" when there is no lead text
    private function drawMetricRow(dc as Dc, w as Number, y as Number, lead as String?, settings as Settings) as Void {
        var metric = metricText(settings.fieldBottom);
        var heart = settings.fieldBottom == 3;
        var icon = settings.fieldBottom == 0 ? _stepsIcon as BitmapResource : null;
        var separator = " \u00B7 ";
        var space = w * 10 / 1000;
        var heartSize = w * 14 / 1000;

        var leadW = lead != null ? dc.getTextWidthInPixels(lead, _cityFont) : 0;
        var separatorW = lead != null && metric != null ? dc.getTextWidthInPixels(separator, _cityFont) : 0;
        var iconW = metric == null ? 0 : icon != null ? icon.getWidth() + space : heart ? 2 * heartSize + space : 0;
        var metricW = metric != null ? dc.getTextWidthInPixels(metric, _cityFont) : 0;
        var x = (w - leadW - separatorW - iconW - metricW) / 2;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        if (lead != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, _cityFont, lead, just);
            x += leadW;
        }
        if (metric == null) {
            return;
        }
        if (separatorW > 0) {
            dc.setColor(0x6A6A6A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, _cityFont, separator, just);
            x += separatorW;
        }
        if (icon != null) {
            dc.drawBitmap(x, y - icon.getHeight() / 2, icon);
        } else if (heart) {
            Icons.heart(dc, x + heartSize, y, heartSize, 0xFF5A6A);
        }
        x += iconW;
        dc.setColor(heart ? 0xFF5A6A : 0x5BA8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _cityFont, metric, just);
    }

    private function metricText(kind as Number) as String? {
        var info = ActivityMonitor.getInfo();
        switch (kind) {
            case 0:
                return info.steps != null ? groupThousands(info.steps) : "--";
            case 1:
                if (info.distance == null) {
                    return "--";
                }
                var miles = System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
                var km = info.distance / 100000.0f;
                return (miles ? km * 0.621371f : km).format("%.1f") + (miles ? " mi" : " km");
            case 2:
                return info.calories != null ? activeCalories(info.calories) + " kcal" : "--";
            case 3:
                var activity = Activity.getActivityInfo();
                var bpm = activity != null ? activity.currentHeartRate : null;
                return bpm != null ? bpm.toString() : "--";
            default:
                return null;
        }
    }

    private function activeCalories(total as Number) as Number {
        var profile = UserProfile.getProfile();
        if (profile.weight == null || profile.height == null || profile.birthYear == null) {
            return total;
        }
        var t = System.getClockTime();
        var year = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year as Number;
        return Health.activeCalories(total, profile.weight as Number, profile.height as Number,
            year - (profile.birthYear as Number), profile.gender == UserProfile.GENDER_MALE,
            t.hour * 3600 + t.min * 60 + t.sec);
    }

    private function groupThousands(n as Number) as String {
        var s = n.toString();
        return n >= 1000 ? s.substring(0, s.length() - 3) + "," + s.substring(s.length() - 3, s.length()) : s;
    }
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

(:background)
module Weather {
    enum {
        CLEAR,
        PARTLY,
        CLOUDY,
        FOG,
        DRIZZLE,
        RAIN,
        SNOW,
        SHOWERS,
        THUNDER
    }

    // WMO weather interpretation codes as returned by Open-Meteo
    function group(code as Number) as Number {
        if (code <= 1) {
            return CLEAR;
        } else if (code == 2) {
            return PARTLY;
        } else if (code == 3) {
            return CLOUDY;
        } else if (code <= 48) {
            return FOG;
        } else if (code <= 57) {
            return DRIZZLE;
        } else if (code <= 67) {
            return RAIN;
        } else if (code <= 77) {
            return SNOW;
        } else if (code <= 82) {
            return SHOWERS;
        } else if (code <= 86) {
            return SNOW;
        }
        return THUNDER;
    }

    // Bump when the cached keys change: Storage outlives an app update
    const VERSION = 1;

    function numeric(v) as Boolean {
        return v instanceof Number || v instanceof Float || v instanceof Double;
    }

    function tenths(v as Numeric) as Number {
        return Math.round(v * 10).toNumber();
    }

    function first(list) {
        return list instanceof Array && list.size() > 0 ? list[0] : null;
    }

    // Turns an Open-Meteo reply into the cached shape, or null if any required field is missing or not a number
    function parse(data) as Dictionary? {
        var current = data instanceof Dictionary ? data["current"] : null;
        var daily = data instanceof Dictionary ? data["daily"] : null;
        if (!(current instanceof Dictionary) || !(daily instanceof Dictionary)) {
            return null;
        }
        var t = current["temperature_2m"];
        var code = current["weather_code"];
        var isDay = current["is_day"];
        var wind = current["wind_speed_10m"];
        var hi = first(daily["temperature_2m_max"]);
        var lo = first(daily["temperature_2m_min"]);
        var precip = first(daily["precipitation_probability_max"]);
        if (!numeric(t) || !numeric(code) || !numeric(isDay) || !numeric(wind) || !numeric(hi) || !numeric(lo)) {
            return null;
        }
        return {
            "v" => VERSION,
            "t" => tenths(t),
            "hi" => tenths(hi),
            "lo" => tenths(lo),
            "c" => code.toNumber(),
            "d" => isDay.toNumber(),
            "sr" => minutesOfDay(first(daily["sunrise"])),
            "ss" => minutesOfDay(first(daily["sunset"])),
            "p" => numeric(precip) ? Math.round(precip).toNumber() : 0,
            "wd" => tenths(wind)
        };
    }

    function load() as Dictionary? {
        var data = Application.Storage.getValue("w");
        return data instanceof Dictionary && data["v"] == VERSION ? data : null;
    }

    function current(settings as Settings) as Dictionary? {
        var data = load();
        if (data == null) {
            return null;
        }
        var at = data["at"];
        var maxAge = 3 * 60 * settings.refreshMinutes * (settings.isPowerSaving() ? 2 : 1);
        return at instanceof Number && Time.now().value() - at <= maxAge ? data : null;
    }

    function minutesOfDay(iso) as Number? {
        if (!(iso instanceof String)) {
            return null;
        }
        var t = iso.find("T");
        if (t == null || iso.length() < t + 6) {
            return null;
        }
        var h = iso.substring(t + 1, t + 3).toNumber();
        var m = iso.substring(t + 4, t + 6).toNumber();
        return h != null && m != null ? h * 60 + m : null;
    }

    function temp(tenthsC as Number, fahrenheit as Boolean) as String {
        var v = tenthsC / 10.0f;
        if (fahrenheit) {
            v = v * 9.0f / 5.0f + 32.0f;
        }
        return Math.round(v).toNumber().toString() + "\u00B0";
    }

    function wind(tenthsKmh as Number, fahrenheit as Boolean) as String {
        var v = tenthsKmh / 10.0f;
        if (fahrenheit) {
            return Math.round(v * 0.621371f).toNumber() + " mph";
        }
        return Math.round(v).toNumber() + " km/h";
    }

    function clock(minutes as Number?, is24Hour as Boolean) as String {
        if (minutes == null) {
            return "--:--";
        }
        var h = minutes / 60;
        if (!is24Hour) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format(is24Hour ? "%02d" : "%d") + ":" + (minutes % 60).format("%02d");
    }
}

import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;

(:background)
class WeatherService extends System.ServiceDelegate {
    const CITY_CELLS_PER_DEGREE = 10;

    private var _settings as Settings;
    private var _result as Dictionary = {};
    private var _city as String = "";
    private var _geoKey as String = "";
    private var _latitude as Float = 0.0f;
    private var _longitude as Float = 0.0f;
    private var _cityKey as String = "";

    function initialize() {
        ServiceDelegate.initialize();
        _settings = new Settings();
    }

    function onTemporalEvent() as Void {
        if (!_settings.weatherEnabled) {
            Background.exit(null);
            return;
        }
        if (_settings.locationMode == 1 && _settings.cityName.length() > 0) {
            _geoKey = _settings.cityName + "|" + _settings.apiLanguage();
            var known = Application.Storage.getValue("gc");
            if (known instanceof Array && known.size() == 4 && _geoKey.equals(known[0])) {
                _city = known[3] as String;
                fetchWeather(known[1] as Numeric, known[2] as Numeric);
                return;
            }
            get("https://geocoding-api.open-meteo.com/v1/search",
                {"count" => 1, "language" => _settings.apiLanguage(), "name" => _settings.cityName},
                :onGeocode);
            return;
        }
        var loc = lastKnownLocation();
        if (loc == null) {
            Background.exit(null);
            return;
        }
        fetchWeather(loc[0], loc[1]);
    }

    function onGeocode(code as Number, data as Dictionary or String or Null) as Void {
        var results = code == 200 && data instanceof Dictionary ? data["results"] : null;
        if (!(results instanceof Array) || results.size() == 0) {
            Background.exit(null);
            return;
        }
        var place = results[0];
        if (!(place instanceof Dictionary) || !Weather.numeric(place["latitude"]) || !Weather.numeric(place["longitude"])) {
            Background.exit(null);
            return;
        }
        var name = place["name"];
        _city = name instanceof String ? name : "";
        Application.Storage.setValue("gc", [_geoKey, place["latitude"], place["longitude"], _city]);
        fetchWeather(place["latitude"] as Numeric, place["longitude"] as Numeric);
    }

    function onForecast(code as Number, data as Dictionary or String or Null) as Void {
        var parsed = code == 200 ? Weather.parse(data) : null;
        if (parsed == null) {
            Background.exit(null);
            return;
        }
        _result = parsed;
        _result["at"] = Time.now().value();
        if (_city.length() > 0) {
            _result["city"] = _city;
        }
        resolveCity();
    }

    private function resolveCity() as Void {
        if (_result.hasKey("city") || _settings.cityLabel.length() > 0) {
            Background.exit(_result);
            return;
        }
        _cityKey = Math.round(_latitude * CITY_CELLS_PER_DEGREE).toNumber() + "," +
            Math.round(_longitude * CITY_CELLS_PER_DEGREE).toNumber() + "," + _settings.apiLanguage();
        var cached = Application.Storage.getValue("cc");
        if (cached instanceof Array && cached.size() == 2 && _cityKey.equals(cached[0])) {
            _result["city"] = cached[1];
            Background.exit(_result);
            return;
        }
        // The cache cell is 0.1 degrees, so there is no reason to tell a third party the position more exactly
        get("https://nominatim.openstreetmap.org/reverse",
            {"format" => "jsonv2", "lat" => _latitude.format("%.2f"), "lon" => _longitude.format("%.2f"),
             "zoom" => 12, "addressdetails" => 1, "accept-language" => _settings.apiLanguage()},
            :onCity);
    }

    function onCity(code as Number, data as Dictionary or String or Null) as Void {
        var address = code == 200 && data instanceof Dictionary ? data["address"] : null;
        if (address instanceof Dictionary) {
            var kinds = ["city", "town", "village", "hamlet", "municipality", "county"];
            for (var i = 0; i < kinds.size(); i++) {
                var name = address[kinds[i]];
                if (name instanceof String) {
                    _result["city"] = name;
                    Application.Storage.setValue("cc", [_cityKey, name]);
                    break;
                }
            }
        }
        Background.exit(_result);
    }

    private function fetchWeather(lat as Numeric, lon as Numeric) as Void {
        _latitude = lat.toFloat();
        _longitude = lon.toFloat();
        get("https://api.open-meteo.com/v1/forecast", {
            "latitude" => _latitude.format("%.3f"),
            "longitude" => _longitude.format("%.3f"),
            "current" => "temperature_2m,weather_code,is_day,wind_speed_10m",
            "daily" => "temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max",
            "forecast_days" => 1,
            "timezone" => "auto"
        }, :onForecast);
    }

    private function get(url as String, params as Dictionary, callback as Symbol) as Void {
        Communications.makeWebRequest(url, params, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {"User-Agent" => "SensoryGarminWatchFace/1.0"},
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(callback));
    }

    private function lastKnownLocation() as Array? {
        var saved = Application.Storage.getValue("loc");
        if (saved instanceof Array) {
            return saved;
        }
        var info = Position.getInfo();
        if (info.position != null && info.accuracy != Position.QUALITY_NOT_AVAILABLE) {
            return info.position.toDegrees();
        }
        return null;
    }
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

(:background)
class Settings {
    enum Language {
        ENGLISH,
        RUSSIAN,
        GERMAN,
        POLISH,
        SPANISH,
        BELARUSIAN
    }

    enum Typeface {
        ROBOTO,
        INTER
    }

    const API_LANGUAGES = ["en", "ru", "de", "pl", "es", "be"];

    var language as Number;
    var timeFormat as Number;
    var tileTheme as Number;
    var fontFamily as Number;
    var fieldBottom as Number;
    var dateFormat as Number;
    var weatherEnabled as Boolean;
    var fieldWeather as Number;
    var tempUnit as Number;
    var locationMode as Number;
    var cityName as String;
    var cityLabel as String;
    var refreshMinutes as Number;
    var powerSaving as Number;

    function initialize() {
        language = resolveLanguage(number("Language", 0));
        timeFormat = number("TimeFormat", 0);
        tileTheme = number("TileTheme", 0);
        fontFamily = number("Typeface", 0);
        fieldBottom = number("FieldBottom", 0);
        dateFormat = number("DateFormat", 0);
        var enabled = Application.Properties.getValue("WeatherEnabled");
        weatherEnabled = enabled instanceof Boolean ? enabled : true;
        fieldWeather = number("FieldWeather", 0);
        tempUnit = number("TempUnit", 0);
        locationMode = number("LocationMode", 0);
        cityName = text("CityName");
        cityLabel = text("CityLabel");
        refreshMinutes = number("RefreshMinutes", 30);
        powerSaving = number("PowerSaving", 0);
    }

    function apiLanguage() as String {
        return API_LANGUAGES[language];
    }

    function is24Hour() as Boolean {
        if (timeFormat == 1) {
            return true;
        }
        if (timeFormat == 2) {
            return false;
        }
        return System.getDeviceSettings().is24Hour;
    }

    function isPowerSaving() as Boolean {
        if (powerSaving == 1) {
            return true;
        }
        if (powerSaving == 2) {
            return false;
        }
        return System.getSystemStats().battery <= 20 || System.getDeviceSettings().doNotDisturb;
    }

    private function number(key as String, fallback as Number) as Number {
        var v = Application.Properties.getValue(key);
        return v instanceof Number ? v : fallback;
    }

    private function text(key as String) as String {
        var v = Application.Properties.getValue(key);
        return v instanceof String ? v : "";
    }

    private function resolveLanguage(setting as Number) as Number {
        if (setting > 0) {
            return setting - 1;
        }
        switch (System.getDeviceSettings().systemLanguage) {
            case System.LANGUAGE_RUS:
                return RUSSIAN;
            case System.LANGUAGE_DEU:
                return GERMAN;
            case System.LANGUAGE_POL:
                return POLISH;
            case System.LANGUAGE_SPA:
                return SPANISH;
            default:
                return ENGLISH;
        }
    }
}

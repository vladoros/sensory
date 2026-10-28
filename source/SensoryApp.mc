import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class SensoryApp extends Application.AppBase {
    private var _weatherKey as String;

    function initialize() {
        AppBase.initialize();
        _weatherKey = weatherKey(new Settings());
    }

    // The settings that change what the weather fetch asks for; the rest never need a new request
    private function weatherKey(s as Settings) as String {
        return s.weatherEnabled.toString() + "," + s.locationMode + "," + s.cityName + "," + s.cityLabel + "," +
            s.language + "," + s.refreshMinutes;
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        scheduleWeather(Weather.current(new Settings()) == null);
        return [new SensoryView()];
    }

    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return [new SettingsMenu(), new SettingsMenuDelegate()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new WeatherService()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        if (data != null) {
            Application.Storage.setValue("w", data);
        }
        scheduleWeather(false);
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() as Void {
        var key = weatherKey(new Settings());
        if (!key.equals(_weatherKey)) {
            _weatherKey = key;
            scheduleWeather(true);
        }
        WatchUi.requestUpdate();
    }

    // A one-shot run replaces the recurring event, which comes back only when that run reports in
    // (onBackgroundData); SensoryView asks again if the weather stays stale
    function scheduleWeather(immediately as Boolean) as Void {
        var settings = new Settings();
        try {
            if (!settings.weatherEnabled) {
                Background.deleteTemporalEvent();
            } else if (immediately) {
                // Garmin rejects a run less than 5 minutes after the previous one
                var now = Time.now();
                var last = Background.getLastTemporalEventTime();
                var earliest = last != null ? last.add(new Time.Duration(5 * 60)) : now;
                Background.registerForTemporalEvent(earliest.greaterThan(now) ? earliest : now);
            } else {
                var minutes = settings.refreshMinutes * (settings.isPowerSaving() ? 2 : 1);
                Background.registerForTemporalEvent(new Time.Duration(minutes * 60));
            }
        } catch (e) {
            // Garmin throws if the requested time is invalid; the next call to this function retries
        }
    }
}

import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:debug)
function wednesday() as Gregorian.Info {
    var moment = Gregorian.moment({:year => 2026, :month => 10, :day => 28, :hour => 12});
    return Gregorian.info(moment, Time.FORMAT_SHORT);
}

(:debug)
function settle(flipper as Flipper) as Number {
    var ticks = 0;
    while (flipper.active() && ticks < 100) {
        flipper.tick(ticks * 50);
        ticks++;
    }
    return ticks;
}

(:test)
function dateByLanguage(logger as Logger) as Boolean {
    var info = wednesday();
    Test.assertEqual(Strings.date(0, 0, info), "Wed, Oct 28");
    Test.assertEqual(Strings.date(1, 0, info), "ср, 28 окт");
    Test.assertEqual(Strings.date(2, 0, info), "Mi, 28. Okt");
    Test.assertEqual(Strings.date(3, 0, info), "śr, 28 paź");
    Test.assertEqual(Strings.date(4, 0, info), "mié, 28 oct");
    Test.assertEqual(Strings.date(5, 0, info), "ср, 28 кас");
    return true;
}

(:test)
function longDateByLanguage(logger as Logger) as Boolean {
    var info = wednesday();
    Test.assertEqual(Strings.longDate(0, 0, info), "October 28");
    Test.assertEqual(Strings.longDate(1, 0, info), "28 октября");
    Test.assertEqual(Strings.longDate(2, 0, info), "28. Oktober");
    Test.assertEqual(Strings.longDate(3, 0, info), "28 października");
    Test.assertEqual(Strings.longDate(4, 0, info), "28 de octubre");
    Test.assertEqual(Strings.longDate(5, 0, info), "28 кастрычніка");
    Test.assertEqual(Strings.longDate(0, 1, info), "28.10.2026");
    Test.assertEqual(Strings.WEEKDAYS_FULL[3][info.day_of_week - 1], "Środa");
    return true;
}

(:test)
function dateNumericFormats(logger as Logger) as Boolean {
    var info = wednesday();
    Test.assertEqual(Strings.date(0, 1, info), "Wed, 28.10.2026");
    Test.assertEqual(Strings.date(0, 2, info), "Wed, 28/10/2026");
    Test.assertEqual(Strings.date(0, 3, info), "Wed, 10/28/2026");
    Test.assertEqual(Strings.date(0, 4, info), "Wed, 2026-10-28");
    return true;
}

(:test)
function weatherCodeGroups(logger as Logger) as Boolean {
    Test.assertEqual(Weather.group(0), Weather.CLEAR);
    Test.assertEqual(Weather.group(1), Weather.CLEAR);
    Test.assertEqual(Weather.group(2), Weather.PARTLY);
    Test.assertEqual(Weather.group(3), Weather.CLOUDY);
    Test.assertEqual(Weather.group(45), Weather.FOG);
    Test.assertEqual(Weather.group(53), Weather.DRIZZLE);
    Test.assertEqual(Weather.group(63), Weather.RAIN);
    Test.assertEqual(Weather.group(73), Weather.SNOW);
    Test.assertEqual(Weather.group(81), Weather.SHOWERS);
    Test.assertEqual(Weather.group(86), Weather.SNOW);
    Test.assertEqual(Weather.group(95), Weather.THUNDER);
    return true;
}

(:test)
function weatherFormatting(logger as Logger) as Boolean {
    Test.assertEqual(Weather.temp(254, false), "25°");
    Test.assertEqual(Weather.temp(254, true), "78°");
    Test.assertEqual(Weather.wind(188, false), "19 km/h");
    Test.assertEqual(Weather.wind(188, true), "12 mph");
    Test.assertEqual(Weather.clock(454, true), "07:34");
    Test.assertEqual(Weather.clock(454, false), "7:34");
    Test.assertEqual(Weather.clock(1095, true), "18:15");
    Test.assertEqual(Weather.clock(1095, false), "6:15");
    return true;
}

(:test)
function sunTimesSurviveMissingValues(logger as Logger) as Boolean {
    Test.assertEqual(Weather.minutesOfDay("2026-10-28T06:41"), 401);
    Test.assert(Weather.minutesOfDay(null) == null);
    Test.assert(Weather.minutesOfDay("2026-10-28") == null);
    Test.assertEqual(Weather.clock(null, true), "--:--");
    return true;
}

(:test)
function activeCaloriesSubtractRestingBurn(logger as Logger) as Boolean {
    var weightGrams = 70000;
    var heightCm = 175;
    var age = 30;
    var noon = 43200;
    Test.assertEqual(Math.round(Health.mifflinStJeorRestingKcal(weightGrams, heightCm, age, true)).toNumber(), 1649);
    Test.assertEqual(Health.activeCalories(1500, weightGrams, heightCm, age, true, noon), 676);
    Test.assertEqual(Health.activeCalories(100, weightGrams, heightCm, age, true, noon), 0);
    return true;
}

(:test)
function conditionTextsFollowWeatherGroups(logger as Logger) as Boolean {
    for (var language = 0; language < Strings.CONDITIONS.size(); language++) {
        Test.assertEqual(Strings.CONDITIONS[language].size(), Weather.THUNDER + 1);
    }
    Test.assertEqual(Strings.CONDITIONS[0][Weather.CLEAR], "Clear");
    Test.assertEqual(Strings.CONDITIONS[0][Weather.PARTLY], "Partly cloudy");
    Test.assertEqual(Strings.CONDITIONS[0][Weather.THUNDER], "Thunderstorm");
    return true;
}

(:test)
function flipperFlipsOnce(logger as Logger) as Boolean {
    var flipper = new Flipper("00");
    flipper.set("01", true);
    Test.assert(flipper.active());
    settle(flipper);
    Test.assertEqual(flipper.shown, "01");
    Test.assert(!flipper.active());
    return true;
}

(:test)
function flipperTakesWallClockTime(logger as Logger) as Boolean {
    var flipper = new Flipper("00");
    flipper.set("01", true);
    flipper.tick(1000);
    flipper.tick(1090);
    Test.assert(flipper.active());
    Test.assert(flipper.progress > 0.4f && flipper.progress < 0.6f);
    flipper.tick(1200);
    Test.assertEqual(flipper.shown, "01");
    Test.assert(!flipper.active());
    return true;
}

(:test)
function flipperIgnoresSameText(logger as Logger) as Boolean {
    var flipper = new Flipper("07");
    flipper.set("07", true);
    Test.assert(!flipper.active());
    return true;
}

(:test)
function flipperSkipsAnimationWhenAsked(logger as Logger) as Boolean {
    var flipper = new Flipper("00");
    flipper.set("02", false);
    Test.assertEqual(flipper.shown, "02");
    Test.assert(!flipper.active());
    return true;
}

(:test)
function flipperSpinEndsOnRealTime(logger as Logger) as Boolean {
    var flipper = new Flipper("00");
    flipper.spin("10", 3);
    var ticks = settle(flipper);
    Test.assertEqual(flipper.shown, "10");
    Test.assert(ticks > 3 && ticks < 100);
    return true;
}

(:test)
function flipperFinishJumpsToTarget(logger as Logger) as Boolean {
    var flipper = new Flipper("00");
    flipper.spin("59", 3);
    flipper.tick(0);
    flipper.finish();
    Test.assertEqual(flipper.shown, "59");
    Test.assert(!flipper.active());
    return true;
}

(:test)
function forecastParsing(logger as Logger) as Boolean {
    var reply = {
        "current" => {"temperature_2m" => 12.34, "weather_code" => 61, "is_day" => 1, "wind_speed_10m" => 5.5},
        "daily" => {
            "temperature_2m_max" => [15.0], "temperature_2m_min" => [8.5],
            "sunrise" => ["2026-10-28T07:12"], "sunset" => ["2026-10-28T17:03"],
            "precipitation_probability_max" => [null]
        }
    };
    var parsed = Weather.parse(reply);
    Test.assertMessage(parsed != null, "a complete reply parses");
    var w = parsed as Dictionary;
    Test.assertEqual(w["v"], Weather.VERSION);
    Test.assertEqual(w["t"], 123);
    Test.assertEqual(w["hi"], 150);
    Test.assertEqual(w["lo"], 85);
    Test.assertEqual(w["c"], 61);
    Test.assertEqual(w["sr"], 432);
    Test.assertEqual(w["ss"], 1023);
    Test.assertEqual(w["p"], 0);
    Test.assertEqual(w["wd"], 55);
    return true;
}

(:test)
function forecastWithMissingFieldIsRejected(logger as Logger) as Boolean {
    var reply = {
        "current" => {"temperature_2m" => null, "weather_code" => 61, "is_day" => 1, "wind_speed_10m" => 5.5},
        "daily" => {"temperature_2m_max" => [15.0], "temperature_2m_min" => [8.5]}
    };
    Test.assertMessage(Weather.parse(reply) == null, "a null temperature is rejected");
    Test.assertMessage(Weather.parse({"current" => {}}) == null, "a reply without daily data is rejected");
    Test.assertMessage(Weather.parse(null) == null, "no reply is rejected");
    return true;
}

import Toybox.Lang;
import Toybox.Time.Gregorian;

module Strings {
    const WEEKDAYS = [
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
        ["вс", "пн", "вт", "ср", "чт", "пт", "сб"],
        ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"],
        ["ndz", "pon", "wt", "śr", "czw", "pt", "sob"],
        ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"],
        ["нд", "пн", "аў", "ср", "чц", "пт", "сб"]
    ];

    const MONTHS = [
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
        ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"],
        ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"],
        ["sty", "lut", "mar", "kwi", "maj", "cze", "lip", "sie", "wrz", "paź", "lis", "gru"],
        ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"],
        ["сту", "лют", "сак", "кра", "мая", "чэр", "ліп", "жні", "вер", "кас", "ліс", "сне"]
    ];

    const WEEKDAYS_FULL = [
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"],
        ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"],
        ["Niedziela", "Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota"],
        ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"],
        ["Нядзеля", "Панядзелак", "Аўторак", "Серада", "Чацвер", "Пятніца", "Субота"]
    ];

    // The form used after a day number: genitive in Russian, Polish and Belarusian
    const MONTHS_FULL = [
        ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
        ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"],
        ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
        ["stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca", "lipca", "sierpnia", "września", "października", "listopada", "grudnia"],
        ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
        ["студзеня", "лютага", "сакавіка", "красавіка", "мая", "чэрвеня", "ліпеня", "жніўня", "верасня", "кастрычніка", "лістапада", "снежня"]
    ];

    const CONDITIONS = [
        ["Clear", "Partly cloudy", "Cloudy", "Fog", "Drizzle", "Rain", "Snow", "Showers", "Thunderstorm"],
        ["Ясно", "Переменно", "Облачно", "Туман", "Морось", "Дождь", "Снег", "Ливень", "Гроза"],
        ["Klar", "Wolkig", "Bewölkt", "Nebel", "Nieselregen", "Regen", "Schnee", "Schauer", "Gewitter"],
        ["Bezchmurnie", "Zachmurz.", "Pochmurno", "Mgła", "Mżawka", "Deszcz", "Śnieg", "Opady", "Burza"],
        ["Despejado", "Parc. nublado", "Nublado", "Niebla", "Llovizna", "Lluvia", "Nieve", "Chubascos", "Tormenta"],
        ["Ясна", "Пераменна", "Воблачна", "Туман", "Імжа", "Дождж", "Снег", "Ліўні", "Навальніца"]
    ];

    function date(language as Number, format as Number, info as Gregorian.Info) as String {
        var weekday = WEEKDAYS[language][info.day_of_week - 1];
        if (format != 0) {
            return weekday + ", " + numericDate(format, info);
        }
        var day = info.day as Number;
        var month = MONTHS[language][(info.month as Number) - 1];
        switch (language) {
            case 0:
                return weekday + ", " + month + " " + day;
            case 2:
                return weekday + ", " + day + ". " + month;
            default:
                return weekday + ", " + day + " " + month;
        }
    }

    function longDate(language as Number, format as Number, info as Gregorian.Info) as String {
        if (format != 0) {
            return numericDate(format, info);
        }
        var day = info.day as Number;
        var month = MONTHS_FULL[language][(info.month as Number) - 1];
        switch (language) {
            case 0:
                return month + " " + day;
            case 2:
                return day + ". " + month;
            case 4:
                return day + " de " + month;
            default:
                return day + " " + month;
        }
    }

    function numericDate(format as Number, info as Gregorian.Info) as String {
        var day = (info.day as Number).format("%02d");
        var month = (info.month as Number).format("%02d");
        var year = info.year as Number;
        switch (format) {
            case 2:
                return day + "/" + month + "/" + year;
            case 3:
                return month + "/" + day + "/" + year;
            case 4:
                return year + "-" + month + "-" + day;
            default:
                return day + "." + month + "." + year;
        }
    }
}

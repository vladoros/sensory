import Toybox.Lang;
import Toybox.Math;

module Health {
    const SECONDS_PER_DAY = 86400;

    function mifflinStJeorRestingKcal(weightGrams as Number, heightCm as Number, age as Number, male as Boolean) as Float {
        return 10.0f * weightGrams / 1000.0f + 6.25f * heightCm - 5.0f * age + (male ? 5.0f : -161.0f);
    }

    function activeCalories(total as Number, weightGrams as Number, heightCm as Number, age as Number,
                            male as Boolean, secondsSinceMidnight as Number) as Number {
        var restingSoFar = mifflinStJeorRestingKcal(weightGrams, heightCm, age, male) * secondsSinceMidnight / SECONDS_PER_DAY;
        var rested = Math.round(restingSoFar).toNumber();
        return total > rested ? total - rested : 0;
    }
}

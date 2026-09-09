using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// The Hindu lunar month a date falls in, in both reckonings.
/// [Amanta] is the month by the South/West Indian system, [Purnimanta] by the
/// North Indian one — they carry the same name through a Shukla Paksha and
/// differ by one month through a Krishna Paksha.
/// </summary>
public record HinduLunarMonthInfo(string Amanta, string Purnimanta, string AmantaHindi, string PurnimantaHindi);

/// <summary>
/// Names the Hindu lunar month for a given moment.
///
/// A lunar month runs new moon to new moon, and takes its name from the solar
/// sign (rashi) the Sun occupies at the new moon that opens it: a new moon in
/// Meena opens Chaitra, one in Mesha opens Vaishakha, and so on round.
///
/// Two reckonings share those names but cut the month at different points:
///
///   Amanta      new moon to new moon. Standard in the south and west.
///   Purnimanta  full moon to full moon. Standard across the Hindi-speaking
///               north, and the one a "Hindi calendar" means.
///
/// Through a Shukla Paksha (waxing half) both agree. Through a Krishna Paksha
/// they differ by exactly one month, because Purnimanta has already rolled
/// over at the full moon while Amanta waits for the new moon. Both are
/// returned rather than one being picked, since which is "correct" depends
/// entirely on where the reader is from.
///
/// Adhika (leap) months are NOT handled. Roughly every third year an extra
/// month is inserted and both names shift for its duration; detecting one
/// needs a check for two new moons inside a single solar sign. Left out
/// deliberately rather than approximated — see TASKLIST.md.
/// </summary>
public static class HinduLunarMonthCalculator
{
    private static readonly string[] MonthNames =
    [
        "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
        "Ashwin", "Kartik", "Margashirsha", "Pausha", "Magha", "Phalguna",
    ];

    private static readonly string[] MonthNamesHindi =
    [
        "चैत्र", "वैशाख", "ज्येष्ठ", "आषाढ़", "श्रावण", "भाद्रपद",
        "आश्विन", "कार्तिक", "मार्गशीर्ष", "पौष", "माघ", "फाल्गुन",
    ];

    /// <param name="paksha">"Shukla" or "Krishna" — PanchangService already
    /// derives this from the same Sun/Moon angle, so it's passed in rather
    /// than recomputed and risking the two disagreeing at a boundary.</param>
    public static HinduLunarMonthInfo Compute(AstroTime time, IAyanamsaService ayanamsa, string paksha)
    {
        // The new moon that opened the current lunar month. Searched backwards
        // over 31 days: a lunation is ~29.53 days, so that window always
        // contains exactly one and never reaches into the one before.
        var newMoon = Astronomy.SearchMoonPhase(0.0, time, -31.0)
            ?? throw new InvalidOperationException(
                $"No new moon found in the 31 days before {time}.");

        var sunSidereal = VedicMath.Normalize(
            Astronomy.SunPosition(newMoon).elon - ayanamsa.LahiriDegrees(newMoon));

        // A new moon in Meena (sign 11) opens Chaitra (0), so the month index
        // is one past the Sun's sign.
        var amantaIndex = (VedicMath.SignIndex(sunSidereal) + 1) % 12;

        // Purnimanta rolled over at the preceding full moon, so through the
        // waning half it already carries the next month's name.
        var purnimantaIndex = paksha == "Krishna" ? (amantaIndex + 1) % 12 : amantaIndex;

        return new HinduLunarMonthInfo(
            MonthNames[amantaIndex],
            MonthNames[purnimantaIndex],
            MonthNamesHindi[amantaIndex],
            MonthNamesHindi[purnimantaIndex]);
    }
}

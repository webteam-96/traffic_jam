namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// Static lookup data for Panchang — the 30 Tithi names, 27 Yoga names, 11
/// Karana names (4 fixed + 7 movable, see KaranaName), and the weekday ->
/// daylight-octant tables for Rahu Kaal / Yamaganda / Gulika Kaal. Verified
/// against an independent open-source implementation (see
/// PanchangServiceTests) rather than trusted from memory alone, since a
/// wrong weekday table would silently produce a wrong "inauspicious time"
/// warning for users.
/// </summary>
public static class PanchangNames
{
    public static readonly string[] TithiNames =
    [
        "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami",
        "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima",
        "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami",
        "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Amavasya",
    ];

    public static readonly string[] YogaNames =
    [
        "Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda", "Sukarma", "Dhriti",
        "Shoola", "Ganda", "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra", "Siddhi", "Vyatipata",
        "Variyana", "Parigha", "Shiva", "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra", "Vaidhriti",
    ];

    private static readonly string[] MovableKaranaNames =
        ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti"];

    /// <summary>
    /// Karana name for slot 0-59 (each half a Tithi, 6°). Slot 0 and the
    /// last 3 slots (57-59) are the four "fixed" Karanas that occur only
    /// once per lunar month; the 7 movable Karanas fill the other 56 slots,
    /// repeating 8 times.
    /// </summary>
    public static string KaranaName(int slot) => slot switch
    {
        0 => "Kimstughna",
        57 => "Shakuni",
        58 => "Chatushpada",
        59 => "Naga",
        _ => MovableKaranaNames[(slot - 1) % 7],
    };

    /// <summary>1-indexed daylight octant (of 8) for Rahu Kaal, by DayOfWeek (Sunday=0).</summary>
    public static readonly int[] RahuKaalOctant = [8, 2, 7, 5, 6, 4, 3];

    /// <summary>1-indexed daylight octant (of 8) for Yamaganda Kaal, by DayOfWeek (Sunday=0).</summary>
    public static readonly int[] YamagandaOctant = [5, 4, 3, 2, 1, 7, 6];

    /// <summary>1-indexed daylight octant (of 8) for Gulika Kaal, by DayOfWeek (Sunday=0).</summary>
    public static readonly int[] GulikaOctant = [7, 6, 5, 4, 3, 2, 1];
}

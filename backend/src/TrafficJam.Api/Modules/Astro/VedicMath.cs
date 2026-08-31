namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// Pure degree-arithmetic on a sidereal ecliptic longitude — sign, Nakshatra,
/// and Navamsha (D9). No astronomy calls here; these are the same formulas
/// regardless of which engine produced the longitude.
/// </summary>
public static class VedicMath
{
    public static readonly string[] SignNames =
    [
        "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
        "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
    ];

    public static readonly string[] NakshatraNames =
    [
        "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra",
        "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni",
        "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha", "Jyeshtha",
        "Mula", "Purva Ashadha", "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha",
        "Purva Bhadrapada", "Uttara Bhadrapada", "Revati",
    ];

    private const double DegreesPerSign = 30.0;
    private const double DegreesPerNakshatra = 360.0 / 27.0; // 13°20'
    private const double DegreesPerPada = DegreesPerNakshatra / 4.0; // 3°20'
    private const double DegreesPerNavamsha = DegreesPerSign / 9.0; // 3°20' — same width as a Pada

    /// <summary>Wraps a longitude into [0, 360).</summary>
    public static double Normalize(double degrees)
    {
        var d = degrees % 360.0;
        return d < 0 ? d + 360.0 : d;
    }

    public static int SignIndex(double siderealLongitude) =>
        (int)(Normalize(siderealLongitude) / DegreesPerSign) % 12;

    /// <summary>Whole-sign house (1-12) a sign falls in, counting the reference sign (Lagna, Moon, ...) as house 1.</summary>
    public static int HouseFromSign(int signIndex, int referenceSignIndex) =>
        ((signIndex - referenceSignIndex + 12) % 12) + 1;

    public static double DegreeInSign(double siderealLongitude) =>
        Normalize(siderealLongitude) % DegreesPerSign;

    public static (int NakshatraIndex, int Pada) Nakshatra(double siderealLongitude)
    {
        var lon = Normalize(siderealLongitude);
        var nakshatraIndex = (int)(lon / DegreesPerNakshatra) % 27;
        var pada = (int)((lon % DegreesPerNakshatra) / DegreesPerPada) + 1;
        return (nakshatraIndex, pada);
    }

    /// <summary>How far the longitude has progressed into its current Nakshatra, in degrees [0, 13°20').</summary>
    public static double DegreeIntoNakshatra(double siderealLongitude) =>
        Normalize(siderealLongitude) % DegreesPerNakshatra;

    public const double NakshatraSpanDegrees = DegreesPerNakshatra;

    /// <summary>
    /// Navamsha (D9) sign index, 0=Aries. Each sign holds nine 3°20' parts;
    /// the classical rule starts counting from a different sign depending on
    /// whether the birth sign is movable/fixed/dual, but that rule collapses
    /// to this single modulo-12 formula because 9 parts x 12 signs = 108,
    /// a multiple of 12 — verified against the classical movable/fixed/dual
    /// starting-sign rule for one example of each modality.
    /// </summary>
    public static int NavamshaSignIndex(double siderealLongitude) =>
        (int)(Normalize(siderealLongitude) / DegreesPerNavamsha) % 12;

    /// <summary>
    /// Position within the current Navamsha, rescaled to a 0-30° range so it
    /// reads the same way DegreeInSign does for a D1 sign.
    /// </summary>
    public static double NavamshaDegreeInSign(double siderealLongitude) =>
        (Normalize(siderealLongitude) % DegreesPerNavamsha) * 9.0;

    private const double DegreesPerDashamsha = DegreesPerSign / 10.0; // 3°
    private const double DegreesPerShastiamsha = DegreesPerSign / 60.0; // 0°30'

    /// <summary>
    /// Dashamsha (D10) sign index, 0=Aries. Each sign holds ten 3° parts.
    /// Classical rule (Brihat Parashara Hora Shastra, cross-checked against
    /// an independent open-source implementation — see AstroEngineService's
    /// doc comment): odd signs (Aries, Gemini, Leo, Libra, Sagittarius,
    /// Aquarius) count their ten parts starting from themselves; even signs
    /// start from the 9th sign from themselves. Unlike Navamsha, this doesn't
    /// collapse into one clean formula independent of odd/even (10 doesn't
    /// divide 12 evenly the way 9 does), so the two cases are handled explicitly.
    /// </summary>
    public static int DashamshaSignIndex(double siderealLongitude)
    {
        var signIndex = SignIndex(siderealLongitude);
        var part = (int)(DegreeInSign(siderealLongitude) / DegreesPerDashamsha); // 0-9
        var isOddSign = signIndex % 2 == 0; // 0-indexed even position = 1st/3rd/5th... = classically "odd" sign
        var startOffset = isOddSign ? 0 : 8; // even signs start from the 9th sign from themselves
        return (signIndex + startOffset + part) % 12;
    }

    public static double DashamshaDegreeInSign(double siderealLongitude) =>
        (Normalize(siderealLongitude) % DegreesPerDashamsha) * 10.0;

    /// <summary>
    /// Shashtiamsha (D60) sign index, 0=Aries. Each sign holds sixty 0°30'
    /// parts, always counted starting from the sign itself, cycling through
    /// all 12 signs five times over the 60 parts.
    ///
    /// D60 is genuinely less standardized across classical sources than
    /// D9/D10 — some texts describe an odd/even reversal for the 60 named
    /// *deities* assigned to each part, which some software implementations
    /// extend to reverse the *sign* mapping for even signs too, and some
    /// don't. This uses the simpler, uniform (no reversal) convention, which
    /// matches at least one credible independent open-source implementation
    /// cross-checked during development — flagged here as a documented
    /// choice, not a settled classical fact, should a professional
    /// astrologer's review call for the other convention.
    /// </summary>
    public static int ShastiamshaSignIndex(double siderealLongitude)
    {
        var signIndex = SignIndex(siderealLongitude);
        var part = (int)(DegreeInSign(siderealLongitude) / DegreesPerShastiamsha); // 0-59
        return (signIndex + part) % 12;
    }

    public static double ShastiamshaDegreeInSign(double siderealLongitude) =>
        (Normalize(siderealLongitude) % DegreesPerShastiamsha) * 60.0;
}

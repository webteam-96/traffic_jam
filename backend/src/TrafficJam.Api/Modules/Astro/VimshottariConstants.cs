namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// The fixed Vimshottari 9-lord order and their proportional years — shared
/// by VimshottariDashaService (dividing 120 years / a Dasha period by these
/// proportions) and KpService (dividing a 13°20' Nakshatra span by the exact
/// same proportions to get KP sub-lords). Same classical proportional rule,
/// two different domains (time vs. degrees) — extracted here once a second
/// consumer needed it, to guarantee both always agree on the one true table.
/// </summary>
public static class VimshottariConstants
{
    public static readonly string[] Lords =
        ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"];

    public static readonly double[] Years = [7, 20, 6, 10, 7, 18, 16, 19, 17]; // sums to 120

    public static int LordIndex(string lord) => Array.IndexOf(Lords, lord);
}

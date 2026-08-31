namespace TrafficJam.Api.Modules.Astro;

public record KpLordship(string SignLord, string StarLord, string SubLord, string SubSubLord);

/// <summary>
/// KP (Krishnamurti Paddhati) lordship chain for any sidereal longitude —
/// applies equally to a planet's position or a house cusp's degree, which is
/// why every KP reference calls it a "sign lord / star lord / sub lord"
/// chain rather than something planet-specific.
///
/// Sign Lord: the classical Rashi ruler (Mars rules Aries, etc.) — no
/// research needed, this is completely standard, uncontested Vedic astrology.
///
/// Star Lord: the ruling planet of the Nakshatra the longitude falls in —
/// identical to VimshottariDashaService's Nakshatra-lord lookup (nakshatraIndex % 9).
///
/// Sub Lord (and Sub-Sub Lord, one level deeper): a Nakshatra's 13°20' span
/// is itself divided into 9 unequal parts, proportional to the same
/// Vimshottari years used for Dasha, starting from the Nakshatra's own Star
/// Lord and cycling through the same fixed 9-lord order — precisely the same
/// proportional-subdivision rule VimshottariDashaService applies to a time
/// span, applied here to a span of degrees instead (see VimshottariConstants.cs).
/// Sub-Sub Lord repeats the same division one level further, on the Sub's
/// own (much narrower) span.
/// </summary>
public static class KpLordshipCalculator
{
    private static readonly string[] SignLords =
    [
        "Mars", "Venus", "Mercury", "Moon", "Sun", "Mercury",
        "Venus", "Mars", "Jupiter", "Saturn", "Saturn", "Jupiter",
    ];

    public static KpLordship Compute(double siderealLongitude)
    {
        var signLord = SignLords[VedicMath.SignIndex(siderealLongitude)];

        var (nakshatraIndex, _) = VedicMath.Nakshatra(siderealLongitude);
        var starLordIndex = nakshatraIndex % 9;
        var starLord = VimshottariConstants.Lords[starLordIndex];

        var degreeIntoNakshatra = VedicMath.DegreeIntoNakshatra(siderealLongitude);
        var (subLordIndex, degreeIntoSub, subSpan) = SubdivideByYears(starLordIndex, degreeIntoNakshatra, VedicMath.NakshatraSpanDegrees);
        var subLord = VimshottariConstants.Lords[subLordIndex];

        var (subSubLordIndex, _, _) = SubdivideByYears(subLordIndex, degreeIntoSub, subSpan);
        var subSubLord = VimshottariConstants.Lords[subSubLordIndex];

        return new KpLordship(signLord, starLord, subLord, subSubLord);
    }

    /// <summary>
    /// Divides a span of <paramref name="totalSpanDegrees"/>, starting at
    /// lord <paramref name="startLordIndex"/> and cycling through the fixed
    /// 9-lord order proportionally to their Vimshottari years, and finds
    /// which part <paramref name="degreeInto"/> falls into. Returns that
    /// part's lord index, how far into that part the position sits, and
    /// that part's own width (the two latter values feed the next, finer
    /// level of subdivision — e.g. Sub -> Sub-Sub).
    /// </summary>
    private static (int LordIndex, double DegreeIntoPart, double PartSpan) SubdivideByYears(
        int startLordIndex, double degreeInto, double totalSpanDegrees)
    {
        var cursor = 0.0;
        for (var i = 0; i < 9; i++)
        {
            var lordIndex = (startLordIndex + i) % 9;
            var partSpan = totalSpanDegrees * VimshottariConstants.Years[lordIndex] / 120.0;
            var partEnd = cursor + partSpan;
            if (degreeInto < partEnd || i == 8) // last part absorbs any float rounding right at the boundary
            {
                return (lordIndex, degreeInto - cursor, partSpan);
            }

            cursor = partEnd;
        }

        throw new InvalidOperationException("unreachable — the 9 parts always sum to the full span");
    }
}

namespace TrafficJam.Api.Modules.Astro;

public record DashaPeriod(string Lord, DateTime Start, DateTime End);

/// <summary>
/// MahaTimeline: one full 120-year Vimshottari cycle from birth. CurrentMaha/
/// CurrentAntar/CurrentPratyantar are each the single period, at their level,
/// that contains the moment the chart was computed for — CurrentAntarList and
/// CurrentPratyantarList are that period's own 9-way breakdown.
/// </summary>
public record DashaResult(
    IReadOnlyList<DashaPeriod> MahaTimeline,
    DashaPeriod CurrentMaha,
    IReadOnlyList<DashaPeriod> CurrentAntarList,
    DashaPeriod CurrentAntar,
    IReadOnlyList<DashaPeriod> CurrentPratyantarList);

public interface IDashaService
{
    DashaResult Compute(DateTime birthUtc, double moonSiderealLongitude, DateTime asOfUtc);
}

/// <summary>
/// Vimshottari Dasha — not a new astronomy calculation, a fixed formula on
/// top of the Moon's birth Nakshatra position AstroEngineService already
/// computes (see BACKEND_REQUIREMENTS.md's own framing of this). The 9
/// planetary lords cycle through a fixed 120-year sequence; where a person's
/// life starts in that cycle is fixed by their birth Moon's Nakshatra and
/// exactly how far through it the Moon had progressed.
///
/// Maha/Antar/Pratyantar are the same rule applied recursively three times:
/// a period of duration D, ruled by lord L, splits into 9 sub-periods (one
/// per lord, in the same fixed order, starting from L) each proportional to
/// D * thatLord'sYears / 120. Applying that rule with D = 120 at the top
/// level reproduces the fixed Mahadasha years exactly, which is why one
/// GenerateSubPeriods method serves all three levels — see Compute below.
/// </summary>
public class VimshottariDashaService : IDashaService
{
    private const double DaysPerYear = 365.2425; // Gregorian mean year — negligible vs. a monthly refresh cadence

    public DashaResult Compute(DateTime birthUtc, double moonSiderealLongitude, DateTime asOfUtc)
    {
        var (nakshatraIndex, _) = VedicMath.Nakshatra(moonSiderealLongitude);
        var startLordIndex = nakshatraIndex % 9; // the 27 Nakshatra lords cycle through the same 9, three times over

        var fractionElapsed = VedicMath.DegreeIntoNakshatra(moonSiderealLongitude) / VedicMath.NakshatraSpanDegrees;

        // The birth Mahadasha is partly "used up" before birth, proportional
        // to how far the Moon had already moved through its Nakshatra —
        // equivalently, its nominal (pre-birth) start is this far back.
        var nominalMahaStart = birthUtc.AddDays(-fractionElapsed * VimshottariConstants.Years[startLordIndex] * DaysPerYear);

        var mahaTimeline = GenerateSubPeriods(startLordIndex, nominalMahaStart, 120.0);
        var currentMaha = FindCurrent(mahaTimeline, asOfUtc);

        var currentAntarList = GenerateSubPeriods(VimshottariConstants.LordIndex(currentMaha.Lord), currentMaha.Start, YearsOf(currentMaha));
        var currentAntar = FindCurrent(currentAntarList, asOfUtc);

        var currentPratyantarList = GenerateSubPeriods(VimshottariConstants.LordIndex(currentAntar.Lord), currentAntar.Start, YearsOf(currentAntar));

        return new DashaResult(mahaTimeline, currentMaha, currentAntarList, currentAntar, currentPratyantarList);
    }

    private static List<DashaPeriod> GenerateSubPeriods(int startLordIndex, DateTime start, double parentDurationYears)
    {
        var periods = new List<DashaPeriod>(9);
        var cursor = start;
        for (var i = 0; i < 9; i++)
        {
            var lordIndex = (startLordIndex + i) % 9;
            var durationDays = parentDurationYears * VimshottariConstants.Years[lordIndex] / 120.0 * DaysPerYear;
            var end = cursor.AddDays(durationDays);
            periods.Add(new DashaPeriod(VimshottariConstants.Lords[lordIndex], cursor, end));
            cursor = end;
        }

        return periods;
    }

    private static DashaPeriod FindCurrent(IReadOnlyList<DashaPeriod> periods, DateTime asOf)
    {
        foreach (var p in periods)
        {
            if (asOf >= p.Start && asOf < p.End) return p;
        }

        // asOf outside the generated window (birth in the future, or beyond
        // this one 120-year cycle) — clamp to the nearest end rather than throw.
        return asOf < periods[0].Start ? periods[0] : periods[^1];
    }

    private static double YearsOf(DashaPeriod p) => (p.End - p.Start).TotalDays / DaysPerYear;
}

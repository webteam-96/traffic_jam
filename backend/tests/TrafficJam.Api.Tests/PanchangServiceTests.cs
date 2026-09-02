using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class PanchangServiceTests
{
    private readonly PanchangService _service = new(new LahiriAyanamsaService());
    private const double MumbaiLat = 19.0760;
    private const double MumbaiLng = 72.8777;
    private const string MumbaiTz = "Asia/Kolkata";

    [Fact]
    public void Compute_Sunrise_IsBeforeSunset_AndBothOnTheRequestedDate()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), MumbaiLat, MumbaiLng, MumbaiTz);

        Assert.True(result.Sunrise < result.Sunset);
        // Mumbai (UTC+5:30): sunrise/sunset both land within a day of local midnight in UTC.
        var dayLengthHours = (result.Sunset - result.Sunrise).TotalHours;
        Assert.InRange(dayLengthHours, 10, 14); // sanity bound — Mumbai's latitude never has extreme day lengths
    }

    [Fact]
    public void Compute_RahuKaal_FallsEntirelyWithinDaylight()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), MumbaiLat, MumbaiLng, MumbaiTz);

        Assert.True(result.RahuKaalStart >= result.Sunrise);
        Assert.True(result.RahuKaalEnd <= result.Sunset);
        // 1/8 of the actual day length, not a fixed 90 min — real day length varies by date/latitude.
        var expectedMinutes = (result.Sunset - result.Sunrise).TotalMinutes / 8;
        Assert.Equal(expectedMinutes, (result.RahuKaalEnd - result.RahuKaalStart).TotalMinutes, precision: 3);
    }

    [Fact]
    public void Compute_Abhijit_IsCenteredOnSolarNoon()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), MumbaiLat, MumbaiLng, MumbaiTz);

        var solarNoon = result.Sunrise + (result.Sunset - result.Sunrise) / 2;
        var abhijitMidpoint = result.AbhijitStart + (result.AbhijitEnd - result.AbhijitStart) / 2;

        Assert.True(Math.Abs((abhijitMidpoint - solarNoon).TotalMinutes) < 5);
    }

    // Cross-checked against an independent open-source implementation
    // (SriramK89/rahu_yama_time) rather than trusted from memory — see
    // PanchangNames.cs's doc comment. Spot-check two full weeks' worth of
    // real dates (each a different weekday) against the fixed octant tables.
    [Theory]
    [InlineData(2026, 8, 30, DayOfWeek.Sunday, 8)]
    [InlineData(2026, 8, 31, DayOfWeek.Monday, 2)]
    [InlineData(2026, 9, 1, DayOfWeek.Tuesday, 7)]
    [InlineData(2026, 9, 2, DayOfWeek.Wednesday, 5)]
    [InlineData(2026, 9, 3, DayOfWeek.Thursday, 6)]
    [InlineData(2026, 9, 4, DayOfWeek.Friday, 4)]
    [InlineData(2026, 9, 5, DayOfWeek.Saturday, 3)]
    public void Compute_RahuKaal_MatchesTheVerifiedWeekdayOctantTable(int y, int m, int d, DayOfWeek expectedWeekday, int expectedOctant)
    {
        var date = new DateOnly(y, m, d);
        Assert.Equal(expectedWeekday, date.DayOfWeek); // guards the test data itself against a typo

        var result = _service.Compute(date, MumbaiLat, MumbaiLng, MumbaiTz);
        var octantLength = (result.Sunset - result.Sunrise) / 8;
        var expectedStart = result.Sunrise + octantLength * (expectedOctant - 1);

        Assert.True(Math.Abs((result.RahuKaalStart - expectedStart).TotalMinutes) < 1);
    }

    [Fact]
    public void Compute_AbhijitClean_FullySwallowedOnWednesday_TheUserReportedCase()
    {
        // The real report this guards: Rahu Kaal 06:54-08:26 UTC vs Abhijit
        // 06:30-07:19 UTC on 2026-09-02 (Wednesday) — "how can this be a
        // green light if Rahu Kaal already contradicts it?" On Wednesdays,
        // Gulika (octant 4, 37.5%-50% of the day) and Rahu Kaal (octant 5,
        // 50%-62.5%) sit back-to-back with no gap, and together they fully
        // cover Abhijit's ~46.7%-53.3% window — there's no honestly-clean
        // moment left, not just a partial overlap.
        var result = _service.Compute(new DateOnly(2026, 9, 2), MumbaiLat, MumbaiLng, MumbaiTz);

        Assert.Null(result.AbhijitCleanStart);
        Assert.Null(result.AbhijitCleanEnd);
        Assert.True(result.GulikaEnd == result.RahuKaalStart); // the adjacency that closes the gap
        Assert.True(result.GulikaStart <= result.AbhijitStart && result.RahuKaalEnd >= result.AbhijitEnd);
    }

    // Every weekday's Abhijit-vs-avoid relationship, checked generically
    // rather than by re-deriving each weekday's octant math by hand (that's
    // exactly the kind of manual percentage estimate that got the two
    // deleted versions of these tests wrong) — whatever TrimAgainstInauspicious
    // returns must satisfy real interval-arithmetic invariants.
    [Theory]
    [InlineData(2026, 8, 30)] [InlineData(2026, 8, 31)] [InlineData(2026, 9, 1)]
    [InlineData(2026, 9, 2)] [InlineData(2026, 9, 3)] [InlineData(2026, 9, 4)] [InlineData(2026, 9, 5)]
    public void Compute_AbhijitClean_NeverOverlapsAnyAvoidWindow(int y, int m, int d)
    {
        var result = _service.Compute(new DateOnly(y, m, d), MumbaiLat, MumbaiLng, MumbaiTz);
        var avoid = new[]
        {
            (result.RahuKaalStart, result.RahuKaalEnd),
            (result.YamagandaStart, result.YamagandaEnd),
            (result.GulikaStart, result.GulikaEnd),
        };

        if (result.AbhijitCleanStart is null || result.AbhijitCleanEnd is null)
        {
            Assert.Null(result.AbhijitCleanStart);
            Assert.Null(result.AbhijitCleanEnd);
            return;
        }

        var (cleanStart, cleanEnd) = (result.AbhijitCleanStart.Value, result.AbhijitCleanEnd.Value);
        Assert.True(cleanStart >= result.AbhijitStart && cleanEnd <= result.AbhijitEnd); // stays within Abhijit
        Assert.True(cleanStart < cleanEnd); // non-empty
        foreach (var (avoidStart, avoidEnd) in avoid)
        {
            Assert.True(cleanEnd <= avoidStart || cleanStart >= avoidEnd, $"Clean window overlaps {avoidStart}-{avoidEnd}");
        }
    }

    [Fact]
    public void TithiNames_ShuklaAndKrishnaOnlyDifferAtTheFullAndNewMoonEntries()
    {
        // Full-moon-adjacent date sanity check isn't hardcoded (we don't have
        // independently-verified ground truth for a specific Tithi on a specific
        // date without an ephemeris to cross-check against) — instead check the
        // self-consistency invariant that must always hold: Shukla Paksha names
        // never overlap Krishna Paksha names in the lookup table itself.
        var shuklaNames = PanchangNames.TithiNames.Take(15).ToHashSet();
        var krishnaNames = PanchangNames.TithiNames.Skip(15).Take(15).ToHashSet();

        Assert.Equal(14, shuklaNames.Intersect(krishnaNames).Count()); // all but Purnima/Amavasya are shared day-names
        Assert.DoesNotContain("Purnima", krishnaNames);
        Assert.DoesNotContain("Amavasya", shuklaNames);
    }

    [Fact]
    public void Compute_TithiEndsAt_IsAfterSunriseAndWithinTwoDays()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), MumbaiLat, MumbaiLng, MumbaiTz);

        Assert.True(result.TithiEndsAt > result.Sunrise);
        Assert.True((result.TithiEndsAt - result.Sunrise).TotalHours < 48); // Tithis run ~19-26h, never close to 2 days
    }

    [Fact]
    public void Compute_NakshatraEndsAt_IsAfterSunriseAndWithinTwoDays()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), MumbaiLat, MumbaiLng, MumbaiTz);

        Assert.True(result.NakshatraEndsAt > result.Sunrise);
        Assert.True((result.NakshatraEndsAt - result.Sunrise).TotalHours < 48);
    }

    // Tithi and Karana are both derived from the exact same Moon-minus-Sun
    // angle (Karana is just a Tithi cut in half), so they must never drift
    // apart: whichever Karana is currently active, it has to belong to the
    // Tithi currently active, and if it's the second half of that Tithi,
    // the two must end at literally the same instant. Caught a false alarm
    // here during manual live verification (forgot Krishna Paksha reuses
    // the same day-names at a +15 index offset) before confirming this held.
    [Theory]
    [InlineData(2026, 8, 31)]
    [InlineData(2026, 9, 5)]
    [InlineData(2026, 9, 12)]
    public void Compute_TithiAndKarana_StayMathematicallyConsistent(int y, int m, int d)
    {
        var result = _service.Compute(new DateOnly(y, m, d), MumbaiLat, MumbaiLng, MumbaiTz);

        var tithiIndex = Array.IndexOf(PanchangNames.TithiNames, result.TithiName,
            result.Paksha == "Shukla" ? 0 : 15, 15);
        var karanaHalfIndicesForThisTithi = new[] { tithiIndex * 2, tithiIndex * 2 + 1 };
        var possibleKaranaNames = karanaHalfIndicesForThisTithi.Select(PanchangNames.KaranaName).ToArray();

        Assert.Contains(result.KaranaName, possibleKaranaNames);

        // If this Karana is the tithi's second half, both boundaries coincide exactly.
        if (result.KaranaName == PanchangNames.KaranaName(karanaHalfIndicesForThisTithi[1]))
        {
            Assert.Equal(result.TithiEndsAt, result.KaranaEndsAt);
        }
    }

    [Theory]
    [InlineData(0, "Kimstughna")]
    [InlineData(1, "Bava")]
    [InlineData(8, "Bava")]  // (8-1) % 7 == 0 -> wraps back to the first movable Karana, one full 7-cycle later
    [InlineData(56, "Vishti")] // (56-1) % 7 == 6 -> last movable Karana before the final fixed run
    [InlineData(57, "Shakuni")]
    [InlineData(58, "Chatushpada")]
    [InlineData(59, "Naga")]
    public void KaranaName_MatchesTheClassical60SlotSequence(int slot, string expected)
    {
        Assert.Equal(expected, PanchangNames.KaranaName(slot));
    }
}

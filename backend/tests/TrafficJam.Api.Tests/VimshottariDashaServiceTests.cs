using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class VimshottariDashaServiceTests
{
    private static readonly string[] FixedOrder =
        ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"];

    private readonly VimshottariDashaService _service = new();

    // Moon at exactly 0° Ashwini (start of the zodiac): zero balance elapsed,
    // so the birth Mahadasha should be Ketu's *full* 7 years, starting
    // exactly at birth with no pre-birth backdating — a case simple enough
    // to hand-verify exactly rather than just check invariants on.
    [Fact]
    public void Compute_MoonAtZeroAshwini_BirthMahadashaIsKetuFullSevenYears()
    {
        var birth = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        var result = _service.Compute(birth, moonSiderealLongitude: 0.0, asOfUtc: birth);

        Assert.Equal("Ketu", result.CurrentMaha.Lord);
        Assert.Equal(birth, result.MahaTimeline[0].Start);
        Assert.Equal(7.0, (result.MahaTimeline[0].End - birth).TotalDays / 365.2425, precision: 6);
    }

    // Moon halfway through Ashwini: half of Ketu's 7 years should already be
    // "used up" before birth, so the Mahadasha's nominal start is 3.5 years
    // before birth and only the remaining 3.5-year balance is left to run.
    [Fact]
    public void Compute_MoonHalfwayThroughNakshatra_LeavesHalfTheBalance()
    {
        var birth = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var halfwayThroughAshwini = VedicMath.NakshatraSpanDegrees / 2.0;

        var result = _service.Compute(birth, halfwayThroughAshwini, asOfUtc: birth);

        Assert.Equal("Ketu", result.CurrentMaha.Lord);
        var balanceYears = (result.CurrentMaha.End - birth).TotalDays / 365.2425;
        Assert.Equal(3.5, balanceYears, precision: 3);
    }

    [Theory]
    [InlineData(0)]   // Ashwini -> Ketu
    [InlineData(9)]   // Magha (index 9, 9 % 9 = 0) -> Ketu again, second cycle of the 27
    [InlineData(3)]   // Rohini -> Moon
    public void Compute_MahaTimeline_FollowsFixedLordOrderStartingFromNakshatraLord(int nakshatraIndex)
    {
        var birth = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var longitude = nakshatraIndex * VedicMath.NakshatraSpanDegrees; // 0° into that Nakshatra

        var result = _service.Compute(birth, longitude, asOfUtc: birth);

        var expectedStartIndex = nakshatraIndex % 9;
        for (var i = 0; i < 9; i++)
        {
            var expectedLord = FixedOrder[(expectedStartIndex + i) % 9];
            Assert.Equal(expectedLord, result.MahaTimeline[i].Lord);
        }
    }

    [Fact]
    public void Compute_MahaTimeline_HasNoGapsOrOverlaps_AndSpansExactly120Years()
    {
        var birth = new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc);

        var result = _service.Compute(birth, moonSiderealLongitude: 137.4, asOfUtc: birth);

        for (var i = 0; i < result.MahaTimeline.Count - 1; i++)
        {
            Assert.Equal(result.MahaTimeline[i].End, result.MahaTimeline[i + 1].Start);
        }

        var totalYears = (result.MahaTimeline[^1].End - result.MahaTimeline[0].Start).TotalDays / 365.2425;
        Assert.Equal(120.0, totalYears, precision: 6);
    }

    [Fact]
    public void Compute_CurrentAntarList_StartsWithTheMahadashasOwnLord_AndSumsToItsDuration()
    {
        var birth = new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc);

        var result = _service.Compute(birth, moonSiderealLongitude: 137.4, asOfUtc: birth);

        Assert.Equal(result.CurrentMaha.Lord, result.CurrentAntarList[0].Lord);
        for (var i = 0; i < result.CurrentAntarList.Count - 1; i++)
        {
            Assert.Equal(result.CurrentAntarList[i].End, result.CurrentAntarList[i + 1].Start);
        }

        var mahaDurationYears = (result.CurrentMaha.End - result.CurrentMaha.Start).TotalDays / 365.2425;
        var antarTotalYears = (result.CurrentAntarList[^1].End - result.CurrentAntarList[0].Start).TotalDays / 365.2425;
        Assert.Equal(mahaDurationYears, antarTotalYears, precision: 6);
    }

    [Fact]
    public void Compute_CurrentPratyantarList_StartsWithTheAntardashasOwnLord_AndSumsToItsDuration()
    {
        var birth = new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc);

        var result = _service.Compute(birth, moonSiderealLongitude: 137.4, asOfUtc: birth);

        Assert.Equal(result.CurrentAntar.Lord, result.CurrentPratyantarList[0].Lord);

        var antarDurationYears = (result.CurrentAntar.End - result.CurrentAntar.Start).TotalDays / 365.2425;
        var pratyantarTotalYears =
            (result.CurrentPratyantarList[^1].End - result.CurrentPratyantarList[0].Start).TotalDays / 365.2425;
        Assert.Equal(antarDurationYears, pratyantarTotalYears, precision: 6);
    }

    [Fact]
    public void Compute_AsOfDateInsideALaterMahadasha_PicksThatMahadashaAsCurrent()
    {
        var birth = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        // Moon at 0° Ashwini -> Ketu (7y) then Venus (20y) then Sun (6y)...
        // 40 years in lands inside the Sun Mahadasha (7 + 20 = 27, +6 = 33 -> Sun runs 27-33).
        var asOf = birth.AddYears(30);
        var result = _service.Compute(birth, moonSiderealLongitude: 0.0, asOfUtc: asOf);

        Assert.Equal("Sun", result.CurrentMaha.Lord);
    }
}

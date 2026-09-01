using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class DoshaServiceTests
{
    // ITransitService's fuller signature isn't needed for DoshaService — it
    // only ever asks for Saturn's HouseFromMoon on a given date. This fake
    // lets Sade Sati's day-by-day scan be driven by a hand-picked function
    // instead of real ephemeris, so the boundary math itself is what's
    // under test, not astronomy.
    private sealed class FakeTransitService(Func<DateOnly, int> saturnHouseFromMoon) : ITransitService
    {
        public TransitResult Compute(DateOnly date, int? natalLagnaSignIndex, int natalMoonSignIndex) =>
            new(date, [new TransitPlanet("Saturn", 0, "Aries", 0, false, true, null, saturnHouseFromMoon(date))]);
    }

    private static DoshaService ServiceWith(Func<DateOnly, int> saturnHouseFromMoon) =>
        new(new FakeTransitService(saturnHouseFromMoon));

    private static PlanetPosition P(string planet, int signIndex, double degreeInSign = 15.0) =>
        new(planet, signIndex, VedicMath.SignNames[signIndex], degreeInSign, null, false);

    /// <summary>
    /// A full 9-planet D1 (ComputeKaalSarp always runs alongside Mangal
    /// Dosha and needs all of Sun/Mercury/Jupiter/Saturn/Rahu present, even
    /// when a test only cares about Mars/Moon/Venus) with everything but
    /// Mars/Moon/Venus parked harmlessly in Pisces, overridable per test.
    /// </summary>
    private static List<PlanetPosition> FullChart(int mars, int moon, int venus) =>
    [
        P("Sun", 11), P("Mercury", 11), P("Jupiter", 11), P("Saturn", 11), P("Rahu", 11),
        P("Mars", mars), P("Moon", moon), P("Venus", venus),
    ];

    // ── Mangal Dosha ─────────────────────────────────────────────────────

    [Fact]
    public void MangalDosha_MarsSeventhFromLagnaAndFourthFromMoon_BothFlagged()
    {
        var service = ServiceWith(_ => 0);
        // Mars: Libra. Moon: Cancer -> Libra is house 4 from Cancer.
        // Venus: Capricorn -> Libra is house 10 from Capricorn (not a Mangal house).
        var d1 = FullChart(mars: 6, moon: 3, venus: 9);

        var result = service.ComputeNatalDoshas(d1, ascendantSignIndex: 0); // Aries Lagna -> Libra is house 7

        Assert.True(result.Mangal.FromLagna);
        Assert.Equal(7, result.Mangal.HouseFromLagna);
        Assert.True(result.Mangal.FromMoon);
        Assert.Equal(4, result.Mangal.HouseFromMoon);
        Assert.False(result.Mangal.FromVenus);
        Assert.Equal(10, result.Mangal.HouseFromVenus);
    }

    [Fact]
    public void MangalDosha_MarsThirdFromLagna_IsNotPresentFromLagna()
    {
        var service = ServiceWith(_ => 0);
        var d1 = FullChart(mars: 2, moon: 2, venus: 2);

        var result = service.ComputeNatalDoshas(d1, ascendantSignIndex: 0); // Gemini is house 3 from Aries

        Assert.False(result.Mangal.FromLagna);
        Assert.Equal(3, result.Mangal.HouseFromLagna);
    }

    [Fact]
    public void MangalDosha_UnknownBirthTime_FromLagnaIsNull_ButMoonAndVenusStillComputed()
    {
        var service = ServiceWith(_ => 0);
        var d1 = FullChart(mars: 6, moon: 3, venus: 3);

        var result = service.ComputeNatalDoshas(d1, ascendantSignIndex: null);

        Assert.Null(result.Mangal.FromLagna);
        Assert.Null(result.Mangal.HouseFromLagna);
        Assert.True(result.Mangal.FromMoon); // Libra is house 4 from Cancer — doesn't need a birth time
    }

    [Theory]
    [InlineData(0, true)]  // Aries — Mars' own sign
    [InlineData(7, true)]  // Scorpio — Mars' own sign
    [InlineData(9, true)]  // Capricorn — Mars' exaltation
    [InlineData(1, false)] // Taurus — neither
    public void MangalDosha_MarsOwnOrExaltedSign_FlaggedCorrectly(int marsSign, bool expected)
    {
        var service = ServiceWith(_ => 0);
        var d1 = FullChart(mars: marsSign, moon: 0, venus: 0);

        var result = service.ComputeNatalDoshas(d1, ascendantSignIndex: 0);

        Assert.Equal(expected, result.Mangal.MarsInOwnOrExaltedSign);
    }

    // ── Kaal Sarp Dosha ──────────────────────────────────────────────────

    private static List<PlanetPosition> BaseNineForKaalSarp(double saturnDegreeInSign, int saturnSign = 5) => new()
    {
        P("Sun", 0, 10), P("Moon", 1, 10), P("Mars", 1, 20), P("Mercury", 2, 10),
        P("Jupiter", 3, 10), P("Venus", 4, 10), P("Saturn", saturnSign, saturnDegreeInSign),
        P("Rahu", 0, 0), P("Ketu", 6, 0),
    };

    [Fact]
    public void KaalSarp_AllSevenPlanetsOnOneSideOfRahuKetuAxis_IsPresent()
    {
        var service = ServiceWith(_ => 0);
        // Rahu at Aries 0°; Sun/Moon/Mars/Mercury/Jupiter/Venus/Saturn all
        // between Aries and Libra (the forward 180° arc from Rahu) — none
        // cross to Ketu's side.
        var d1 = BaseNineForKaalSarp(saturnDegreeInSign: 10, saturnSign: 5); // Virgo

        var result = service.ComputeNatalDoshas(d1, ascendantSignIndex: 0);

        Assert.True(result.KaalSarp.IsPresent);
        Assert.Equal("Anant", result.KaalSarp.SubType); // Rahu in house 1 from Aries Lagna
        Assert.Equal(1, result.KaalSarp.RahuHouseFromLagna);
    }

    [Fact]
    public void KaalSarp_OnePlanetOnTheOtherSideOfTheAxis_IsAbsent()
    {
        var service = ServiceWith(_ => 0);
        // Move Saturn past Ketu (Libra 0°) onto the far side of the axis.
        var d1 = BaseNineForKaalSarp(saturnDegreeInSign: 10, saturnSign: 8); // Sagittarius — beyond Ketu

        var result = service.ComputeNatalDoshas(d1, ascendantSignIndex: 0);

        Assert.False(result.KaalSarp.IsPresent);
        Assert.Null(result.KaalSarp.SubType);
    }

    [Fact]
    public void KaalSarp_RahuInSeventhHouse_NamesTakshakSubType()
    {
        var service = ServiceWith(_ => 0);
        var d1 = new List<PlanetPosition>
        {
            P("Sun", 6, 10), P("Moon", 7, 10), P("Mars", 7, 20), P("Mercury", 8, 10),
            P("Jupiter", 9, 10), P("Venus", 10, 10), P("Saturn", 11, 10),
            P("Rahu", 6, 0), P("Ketu", 0, 0),
        };

        // Aries Lagna (0); Rahu in Libra (6) -> house 7.
        var result = service.ComputeNatalDoshas(d1, ascendantSignIndex: 0);

        Assert.True(result.KaalSarp.IsPresent);
        Assert.Equal(7, result.KaalSarp.RahuHouseFromLagna);
        Assert.Equal("Takshak", result.KaalSarp.SubType);
    }

    // ── Sade Sati ────────────────────────────────────────────────────────

    [Fact]
    public void SadeSati_NotInHouse12Or1Or2_IsNotActive()
    {
        var service = ServiceWith(_ => 5); // permanently in house 5 — nowhere near Sade Sati

        var result = service.ComputeSadeSati(natalMoonSignIndex: 0, today: new DateOnly(2026, 1, 1));

        Assert.False(result.IsActive);
        Assert.Null(result.Phase);
    }

    [Theory]
    [InlineData(12, "Rising")]
    [InlineData(1, "Peak")]
    [InlineData(2, "Setting")]
    public void SadeSati_InEachHouse_ReportsTheCorrectPhaseName(int house, string expectedPhase)
    {
        var service = ServiceWith(_ => house);

        var result = service.ComputeSadeSati(natalMoonSignIndex: 0, today: new DateOnly(2026, 1, 1));

        Assert.True(result.IsActive);
        Assert.Equal(expectedPhase, result.Phase);
    }

    // Saturn: house 12 for the first 900 days from an epoch, house 1 for the
    // next 900, house 2 for the next 900, house 3 (exits Sade Sati) after
    // that. "Today" is placed mid-way through the Peak (house 1) phase.
    [Fact]
    public void SadeSati_PhaseAndCycleBoundaries_MatchTheHandComputedDates()
    {
        var epoch = new DateOnly(2020, 1, 1);
        int HouseOn(DateOnly d)
        {
            var days = d.DayNumber - epoch.DayNumber;
            if (days < 900) return 12;
            if (days < 1800) return 1;
            if (days < 2700) return 2;
            return 3;
        }
        var service = ServiceWith(HouseOn);
        var today = epoch.AddDays(1000); // inside the house-1 (Peak) window

        var result = service.ComputeSadeSati(natalMoonSignIndex: 0, today);

        Assert.True(result.IsActive);
        Assert.Equal("Peak", result.Phase);
        Assert.Equal(epoch.AddDays(900), result.PhaseStartedOn);
        Assert.Equal(epoch.AddDays(1799), result.PhaseEndsOn);
        Assert.Equal(epoch.AddDays(2699), result.FullCycleEndsOn);
    }

    [Fact]
    public void SadeSati_TodayIsTheLastDayOfSetting_CycleEndsToday()
    {
        var epoch = new DateOnly(2020, 1, 1);
        int HouseOn(DateOnly d)
        {
            var days = d.DayNumber - epoch.DayNumber;
            return days < 100 ? 2 : 3; // already in the Setting phase, exits after day 100
        }
        var service = ServiceWith(HouseOn);
        var today = epoch.AddDays(99); // the last day still in house 2

        var result = service.ComputeSadeSati(natalMoonSignIndex: 0, today);

        Assert.Equal("Setting", result.Phase);
        Assert.Equal(result.PhaseEndsOn, result.FullCycleEndsOn);
        Assert.Equal(epoch.AddDays(99), result.FullCycleEndsOn);
    }
}

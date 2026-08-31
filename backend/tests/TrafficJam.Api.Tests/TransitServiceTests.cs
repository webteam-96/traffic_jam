using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class TransitServiceTests
{
    private readonly TransitService _service = new(new LahiriAyanamsaService());

    [Fact]
    public void Compute_ReturnsAllNineGrahas()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), natalLagnaSignIndex: 4, natalMoonSignIndex: 9);

        Assert.Equal(9, result.Planets.Count);
        Assert.Contains(result.Planets, p => p.Planet == "Sun");
        Assert.Contains(result.Planets, p => p.Planet == "Rahu");
        Assert.Contains(result.Planets, p => p.Planet == "Ketu");
    }

    [Fact]
    public void Compute_MarksOnlyTheFourSlowMoversAsMajor()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), 4, 9);

        var major = result.Planets.Where(p => p.IsMajor).Select(p => p.Planet).OrderBy(n => n).ToArray();
        Assert.Equal(new[] { "Jupiter", "Ketu", "Rahu", "Saturn" }, major);
    }

    [Fact]
    public void Compute_HouseFromLagna_IsNullWhenLagnaUnknown()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), natalLagnaSignIndex: null, natalMoonSignIndex: 9);

        Assert.All(result.Planets, p => Assert.Null(p.HouseFromLagna));
        Assert.All(result.Planets, p => Assert.InRange(p.HouseFromMoon, 1, 12)); // unaffected by unknown Lagna
    }

    [Fact]
    public void Compute_HouseFromLagnaAndHouseFromMoon_DifferByTheOffsetBetweenThem()
    {
        var result = _service.Compute(new DateOnly(2026, 8, 31), natalLagnaSignIndex: 2, natalMoonSignIndex: 5);

        // Lagna is 3 signs behind Moon (2 -> 5), so for any planet, its house-from-Moon
        // must be exactly 3 less than its house-from-Lagna (mod 12, 1-indexed).
        foreach (var planet in result.Planets)
        {
            var expectedFromMoon = ((planet.HouseFromLagna!.Value - 1 - 3) % 12 + 12) % 12 + 1;
            Assert.Equal(expectedFromMoon, planet.HouseFromMoon);
        }
    }

    [Fact]
    public void Compute_RetrogradeFlags_MatchAFreshAstroEngineComputationOfToday()
    {
        // Cross-check against the independently-built AstroEngineService path
        // (treating "today" as if it were a birth moment) rather than trusting
        // TransitService's own GrahaPositions call in isolation.
        var date = new DateOnly(2026, 8, 31);
        var astroEngine = new AstroEngineService(new LahiriAyanamsaService(), new AscendantCalculator());
        var reference = astroEngine.ComputeBirthChart(
            date.ToDateTime(new TimeOnly(12, 0), DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        var result = _service.Compute(date, natalLagnaSignIndex: 0, natalMoonSignIndex: 0);

        foreach (var planet in result.Planets)
        {
            var expected = reference.D1.Single(p => p.Planet == planet.Planet);
            Assert.Equal(expected.Retrograde, planet.Retrograde);
            Assert.Equal(expected.SignIndex, planet.SignIndex);
        }
    }
}

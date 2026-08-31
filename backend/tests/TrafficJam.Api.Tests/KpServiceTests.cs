using CosineKitty;
using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class KpServiceTests
{
    private readonly KpService _kp = new(new PlacidusHouseCalculator(new AscendantCalculator()), new LahiriAyanamsaService());
    private readonly AstroEngineService _astroEngine = new(new LahiriAyanamsaService(), new AscendantCalculator());

    private static readonly DateTime BirthUtc = new(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc);
    private const double Lat = 19.0760, Lng = 72.8777;

    private KpChartResult Compute()
    {
        var chart = _astroEngine.ComputeBirthChart(BirthUtc, Lat, Lng, timeKnown: true);
        return _kp.Compute(new AstroTime(BirthUtc), Lat, Lng, chart.D1);
    }

    [Fact]
    public void Compute_Cusp1SiderealLongitude_MatchesTheBirthChartsOwnAscendant()
    {
        var chart = _astroEngine.ComputeBirthChart(BirthUtc, Lat, Lng, timeKnown: true);
        var kpChart = _kp.Compute(new AstroTime(BirthUtc), Lat, Lng, chart.D1);

        var cusp1 = kpChart.Cusps.Single(c => c.House == 1);
        var cusp1Longitude = cusp1.SignIndex * 30.0 + cusp1.DegreeInSign;

        // Both ultimately go through the same AscendantCalculator + ayanamsa —
        // this checks the KpService wiring didn't introduce its own divergence.
        var diff = Math.Abs(VedicMath.Normalize(cusp1Longitude) - VedicMath.Normalize(chart.AscendantSiderealLongitude));
        diff = Math.Min(diff, 360 - diff);
        Assert.True(diff < 0.01, $"Cusp 1 {cusp1Longitude:F4}° vs chart Ascendant {chart.AscendantSiderealLongitude:F4}° — diff {diff:F4}°");
    }

    [Fact]
    public void Compute_ReturnsAllNinePlanetsAndAllTwelveCusps()
    {
        var result = Compute();

        Assert.Equal(9, result.Planets.Count);
        Assert.Equal(12, result.Cusps.Count);
        Assert.Equal([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], result.Cusps.Select(c => c.House).OrderBy(h => h));
    }

    [Fact]
    public void Compute_EveryPlanetHouse_IsInRangeOneToTwelve()
    {
        var result = Compute();
        Assert.All(result.Planets, p => Assert.InRange(p.House, 1, 12));
    }

    [Fact]
    public void Compute_EveryPlanetIsListedInExactlyOneCuspsPlanetList()
    {
        var result = Compute();

        foreach (var planet in result.Planets)
        {
            var cuspListingThisPlanet = result.Cusps.Where(c => c.Planets.Contains(planet.Planet)).ToList();
            Assert.Single(cuspListingThisPlanet);
            Assert.Equal(planet.House, cuspListingThisPlanet[0].House);
        }

        Assert.Equal(9, result.Cusps.Sum(c => c.Planets.Count));
    }

    [Fact]
    public void Compute_EachCuspsSignIndex_MatchesItsOwnDegree()
    {
        var result = Compute();

        foreach (var cusp in result.Cusps)
        {
            var reconstructed = cusp.SignIndex * 30.0 + cusp.DegreeInSign;
            Assert.Equal(VedicMath.SignIndex(reconstructed), cusp.SignIndex);
        }
    }

    [Fact]
    public void Compute_EveryLordshipField_IsARealLord()
    {
        var result = Compute();
        var signLords = new[] { "Mars", "Venus", "Mercury", "Moon", "Sun", "Jupiter", "Saturn" };

        foreach (var lordship in result.Planets.Select(p => p.Lordship).Concat(result.Cusps.Select(c => c.Lordship)))
        {
            Assert.Contains(lordship.SignLord, signLords);
            Assert.Contains(lordship.StarLord, VimshottariConstants.Lords);
            Assert.Contains(lordship.SubLord, VimshottariConstants.Lords);
            Assert.Contains(lordship.SubSubLord, VimshottariConstants.Lords);
        }
    }
}

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
        return _kp.Compute(new AstroTime(BirthUtc), Lat, Lng);
    }

    // Cusp 1 and the birth chart's Ascendant are the same point in the sky
    // measured from two different zero points — KP's ayanamsa and Lahiri's. So
    // they must differ by exactly the gap between those two ayanamsas and by
    // nothing else, which pins both the KpService wiring and the fact that KP
    // is genuinely using its own ayanamsa rather than quietly borrowing Lahiri.
    [Fact]
    public void Compute_Cusp1_DiffersFromTheLahiriAscendantByExactlyTheAyanamsaGap()
    {
        var chart = _astroEngine.ComputeBirthChart(BirthUtc, Lat, Lng, timeKnown: true);
        var kpChart = _kp.Compute(new AstroTime(BirthUtc), Lat, Lng);

        var cusp1 = kpChart.Cusps.Single(c => c.House == 1);
        var cusp1Longitude = cusp1.SignIndex * 30.0 + cusp1.DegreeInSign;

        var ayanamsa = new LahiriAyanamsaService();
        var time = new AstroTime(BirthUtc);
        var expectedGap = ayanamsa.LahiriDegrees(time) - ayanamsa.KpDegrees(time);

        var chartAscendant = chart.AscendantSiderealLongitude!.Value;
        var actualGap = VedicMath.Normalize(cusp1Longitude - chartAscendant);

        Assert.Equal(expectedGap, actualGap, precision: 6);
        // Sanity on the gap itself: KP runs a few arcminutes behind Lahiri.
        Assert.InRange(expectedGap * 60.0, 4.0, 7.0);
    }

    [Fact]
    public void Compute_ReturnsAllNinePlanetsAndAllTwelveCusps()
    {
        var result = Compute();

        // 9 grahas + Uranus/Neptune/Pluto + the Ascendant that opens the table.
        Assert.Equal(13, result.Planets.Count);
        Assert.Contains(result.Planets, p => p.Planet == "Uranus");
        Assert.Contains(result.Planets, p => p.Planet == "Neptune");
        Assert.Contains(result.Planets, p => p.Planet == "Pluto");
        Assert.Equal("Ascendant", result.Planets[0].Planet);
        Assert.Equal(12, result.Cusps.Count);
        Assert.Equal([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], result.Cusps.Select(c => c.House).OrderBy(h => h));
    }

    // The Ascendant is cusp 1 in Placidus. The planets table and the cusps
    // table both show it, and a reader comparing the two will notice instantly
    // if they disagree — so it's derived from cusp 1 rather than recomputed.
    [Fact]
    public void Compute_AscendantRow_MatchesCuspOneExactly()
    {
        var result = Compute();

        var asc = result.Planets[0];
        var cusp1 = result.Cusps.Single(c => c.House == 1);

        Assert.Equal(cusp1.SignIndex, asc.SignIndex);
        Assert.Equal(cusp1.DegreeInSign, asc.DegreeInSign);
        Assert.Equal(cusp1.Lordship, asc.Lordship);
        Assert.False(asc.Retrograde);
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

        // Skips the Ascendant: it's a point the houses are measured *from*,
        // not a body sitting in one, so it deliberately isn't listed among a
        // cusp's occupying planets even though it heads the planets table.
        foreach (var planet in result.Planets.Where(p => p.Planet != "Ascendant"))
        {
            var cuspListingThisPlanet = result.Cusps.Where(c => c.Planets.Contains(planet.Planet)).ToList();
            Assert.Single(cuspListingThisPlanet);
            Assert.Equal(planet.House, cuspListingThisPlanet[0].House);
        }

        Assert.Equal(12, result.Cusps.Sum(c => c.Planets.Count));
        Assert.DoesNotContain(result.Cusps, c => c.Planets.Contains("Ascendant"));
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

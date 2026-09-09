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

    // ── KP significators ─────────────────────────────────────────────────
    //
    // KP reads a planet as the agent of the star it sits in, so the four
    // levels are not interchangeable — getting the order or the "owns"
    // derivation wrong changes which house a planet is taken to speak for,
    // which is the whole basis of a KP judgement.

    // Every body the KP table lists gets a row except the Ascendant, which is
    // a point rather than a graha — nine grahas plus the three outer planets.
    [Fact]
    public void Significators_HaveOneRowPerBody_AndNoneForTheAscendant()
    {
        var kp = Compute();

        Assert.Equal(12, kp.Significators.Count);
        Assert.DoesNotContain(kp.Significators, s => s.Planet == "Ascendant");
        Assert.Contains(kp.Significators, s => s.Planet == "Uranus");
        Assert.Contains(kp.Significators, s => s.Planet == "Neptune");
        Assert.Contains(kp.Significators, s => s.Planet == "Pluto");
    }

    [Fact]
    public void Significators_OccupiedHouse_MatchesThePlanetsOwnHouse()
    {
        var kp = Compute();

        foreach (var sig in kp.Significators)
        {
            var planet = kp.Planets.Single(p => p.Planet == sig.Planet);
            Assert.Equal(new[] { planet.House }, sig.Occupies);
        }
    }

    // A planet owns the houses whose CUSP falls in a sign it rules. In
    // Placidus that is not one house per sign: houses are unequal, so a sign
    // can hold two cusps or none, and a whole-sign assumption would quietly
    // hand planets the wrong houses.
    [Fact]
    public void Significators_OwnedHouses_AreTheCuspsInSignsThatPlanetRules()
    {
        var kp = Compute();

        foreach (var sig in kp.Significators)
        {
            var expected = kp.Cusps
                .Where(c => KpLordshipCalculator.RulerOfSign[c.SignIndex] == sig.Planet)
                .Select(c => c.House)
                .Order()
                .ToList();

            Assert.Equal(expected, sig.Owns);
        }
    }

    [Fact]
    public void Significators_StarLordLevels_AreThatStarLordsOwnHousesNotThePlanets()
    {
        var kp = Compute();

        foreach (var sig in kp.Significators)
        {
            var starLord = kp.Planets.Single(p => p.Planet == sig.Planet).Lordship.StarLord;
            var starLordPlanet = kp.Planets.Single(p => p.Planet == starLord);

            Assert.Equal(new[] { starLordPlanet.House }, sig.StarLordOccupies);

            var expectedOwns = kp.Cusps
                .Where(c => KpLordshipCalculator.RulerOfSign[c.SignIndex] == starLord)
                .Select(c => c.House)
                .Order()
                .ToList();
            Assert.Equal(expectedOwns, sig.StarLordOwns);
        }
    }

    // Rahu, Ketu and the three outer planets rule no sign, so they own
    // nothing. Pinned deliberately for the nodes: some KP schools substitute
    // their dispositor or a conjoined planet, and if that is ever adopted this
    // test is the thing that should fail first. See TASKLIST.md.
    [Theory]
    [InlineData("Rahu")]
    [InlineData("Ketu")]
    [InlineData("Uranus")]
    [InlineData("Neptune")]
    [InlineData("Pluto")]
    public void Significators_BodiesWithNoRulership_OwnNoHouses(string planet)
    {
        var kp = Compute();

        Assert.Empty(kp.Significators.Single(s => s.Planet == planet).Owns);
    }

    // The other three levels ARE computable for an outer planet: it sits in a
    // nakshatra so it has a star lord, and it occupies a house. Only "owns" is
    // empty — so the row is real, not a placeholder.
    [Theory]
    [InlineData("Uranus")]
    [InlineData("Neptune")]
    [InlineData("Pluto")]
    public void Significators_OuterPlanets_StillCarryTheOtherThreeLevels(string planet)
    {
        var kp = Compute();

        var sig = kp.Significators.Single(s => s.Planet == planet);

        Assert.NotEmpty(sig.StarLordOccupies);
        Assert.Single(sig.Occupies);
        Assert.All(sig.Occupies, h => Assert.InRange(h, 1, 12));
    }

    [Fact]
    public void Significators_EveryHouseNumber_IsInRangeAndUnique()
    {
        var kp = Compute();

        foreach (var sig in kp.Significators)
        {
            foreach (var level in new[] { sig.StarLordOccupies, sig.StarLordOwns, sig.Occupies, sig.Owns })
            {
                Assert.All(level, h => Assert.InRange(h, 1, 12));
                Assert.Equal(level.Distinct().Count(), level.Count);
                Assert.Equal(level.Order().ToList(), level);
            }
        }
    }

    // ── Uranus, Neptune, Pluto ───────────────────────────────────────────
    //
    // The outer planets appear in the KP table and nowhere else. They are the
    // only bodies here that classical Vedic astrology has no rules for, so the
    // things worth pinning are that they are present, that their houses are
    // read off the real Placidus cusps rather than assumed whole-sign, and
    // that their positions match an independent ephemeris.

    [Fact]
    public void Compute_IncludesTheThreeOuterPlanets()
    {
        var kp = Compute();

        Assert.Contains(kp.Planets, p => p.Planet == "Uranus");
        Assert.Contains(kp.Planets, p => p.Planet == "Neptune");
        Assert.Contains(kp.Planets, p => p.Planet == "Pluto");
    }

    // Houses come from HouseFromCusps, so each outer planet's longitude must
    // genuinely fall inside the span its house claims. A whole-sign shortcut
    // would pass on most charts and quietly fail near a cusp, which is exactly
    // where it matters.
    [Fact]
    public void Compute_OuterPlanetHouses_LieInsideTheirOwnPlacidusSpan()
    {
        var kp = Compute();
        var cusps = kp.Cusps.ToDictionary(c => c.House, c => c.SignIndex * 30.0 + c.DegreeInSign);

        foreach (var planet in kp.Planets.Where(p =>
                     p.Planet is "Uranus" or "Neptune" or "Pluto"))
        {
            var longitude = planet.SignIndex * 30.0 + planet.DegreeInSign;
            var start = cusps[planet.House];
            var end = cusps[planet.House % 12 + 1];

            var span = VedicMath.Normalize(end - start);
            var offset = VedicMath.Normalize(longitude - start);

            Assert.True(offset < span,
                $"{planet.Planet} at {longitude:F3}° is outside house {planet.House} " +
                $"({start:F3}°..{end:F3}°)");
        }
    }

    // Sidereal positions for 24 Oct 1988 04:42 UTC on the KP ayanamsa. Checked
    // by converting back the way a reader can audit them: add the ~23.59°
    // Krishnamurti ayanamsa for late 1988 and the tropical positions come out
    // as Uranus 28°01' Sagittarius, Neptune 7°45' Capricorn, Pluto 12°02'
    // Scorpio — which is where each of them stood that week. The 0.3°
    // tolerance is far tighter than a sign or a house boundary while leaving
    // room for ayanamsa variants.
    [Theory]
    [InlineData("Uranus", 8, 4.428)]    // sidereal Sagittarius
    [InlineData("Neptune", 8, 14.156)]  // sidereal Sagittarius
    [InlineData("Pluto", 6, 18.442)]    // sidereal Libra
    public void Compute_OuterPlanetPositions_MatchAnIndependentEphemeris(
        string planet, int expectedSignIndex, double expectedDegreeInSign)
    {
        var kp = Compute();

        var actual = kp.Planets.Single(p => p.Planet == planet);

        Assert.Equal(expectedSignIndex, actual.SignIndex);
        Assert.InRange(actual.DegreeInSign, expectedDegreeInSign - 0.3, expectedDegreeInSign + 0.3);
    }

    // All three outer planets station direct in the autumn and were direct by
    // late October 1988. Getting a retrograde flag backwards is invisible in a
    // position but changes how the row reads, so it is pinned separately.
    [Theory]
    [InlineData("Uranus")]
    [InlineData("Neptune")]
    [InlineData("Pluto")]
    public void Compute_OuterPlanets_WereAllDirectInLateOctober1988(string planet)
    {
        var kp = Compute();

        Assert.False(kp.Planets.Single(p => p.Planet == planet).Retrograde);
    }
}

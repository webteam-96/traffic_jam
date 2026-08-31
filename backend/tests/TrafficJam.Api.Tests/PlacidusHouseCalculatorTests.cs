using CosineKitty;
using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class PlacidusHouseCalculatorTests
{
    private readonly PlacidusHouseCalculator _calculator = new(new AscendantCalculator());
    private readonly AscendantCalculator _ascendant = new();

    [Theory]
    [InlineData(19.0760, 72.8777)]   // Mumbai
    [InlineData(28.6139, 77.2090)]   // Delhi
    [InlineData(-33.8688, 151.2093)] // Sydney (southern hemisphere)
    [InlineData(51.5072, -0.1276)]   // London (western longitude)
    public void Cusps_House1_MatchesTheIndependentlyBuiltAscendantCalculator(double lat, double lng)
    {
        var time = new AstroTime(new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc));

        var cusps = _calculator.Cusps(time, lat, lng);
        var expectedAscendant = _ascendant.TropicalAscendant(time, lat, lng);

        var diff = Math.Abs(VedicMath.Normalize(cusps[0]) - VedicMath.Normalize(expectedAscendant));
        diff = Math.Min(diff, 360 - diff);
        Assert.True(diff < 0.01, $"Cusp 1 {cusps[0]:F4}° vs Ascendant {expectedAscendant:F4}° — diff {diff:F4}°");
    }

    [Theory]
    [InlineData(19.0760, 72.8777)]
    [InlineData(-33.8688, 151.2093)]
    public void Cusps_House10_SatisfiesItsOwnMeridianDefinition(double lat, double lng)
    {
        var time = new AstroTime(new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc));
        var ramc = VedicMath.Normalize(Astronomy.SiderealTime(time) * 15.0 + lng);

        var cusps = _calculator.Cusps(time, lat, lng);

        // Independently recompute RA of the cusp-10 longitude via the same
        // rotation primitives, and confirm it lands on RAMC — MC's defining
        // condition — rather than trusting the solver produced a self-consistent
        // answer just because it converged.
        var rad = cusps[9] * Math.PI / 180.0;
        var eclVector = new AstroVector(Math.Cos(rad), Math.Sin(rad), 0, time);
        var eqdVector = Astronomy.RotateVector(Astronomy.Rotation_ECT_EQD(time), eclVector);
        var eq = Astronomy.EquatorFromVector(eqdVector);
        var raDeg = VedicMath.Normalize(eq.ra * 15.0);

        var diff = Math.Abs(raDeg - ramc);
        diff = Math.Min(diff, 360 - diff);
        Assert.True(diff < 0.01, $"Cusp 10's RA {raDeg:F4}° vs RAMC {ramc:F4}° — diff {diff:F4}°");
    }

    [Theory]
    [InlineData(19.0760, 72.8777)]
    [InlineData(-33.8688, 151.2093)]
    public void Cusps_OppositeHousesAreExactly180DegreesApart(double lat, double lng)
    {
        var time = new AstroTime(new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc));
        var cusps = _calculator.Cusps(time, lat, lng);

        for (var house = 0; house < 6; house++)
        {
            var diff = VedicMath.Normalize(cusps[house + 6] - cusps[house]);
            Assert.Equal(180.0, diff, precision: 6);
        }
    }

    [Fact]
    public void Cusps_AllTwelveAreDistinctAndValid()
    {
        var time = new AstroTime(new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc));
        var cusps = _calculator.Cusps(time, 19.0760, 72.8777);

        Assert.Equal(12, cusps.Length);
        Assert.All(cusps, c => Assert.InRange(c, 0.0, 360.0));
        Assert.Equal(12, cusps.Select(c => Math.Round(c, 6)).Distinct().Count());
    }

    // Houses progress in a single consistent rotational direction around the
    // ecliptic (11 and 12 both sit strictly between the MC and the
    // Ascendant, in that order, going the short way) — verified at a
    // moderate latitude where this is unambiguous.
    [Fact]
    public void Cusps_11And12_FallBetweenMCAndAscendantInOrder()
    {
        var time = new AstroTime(new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc));
        var cusps = _calculator.Cusps(time, 19.0760, 72.8777);

        var mc = cusps[9];
        var cusp11 = VedicMath.Normalize(cusps[10] - mc);
        var cusp12 = VedicMath.Normalize(cusps[11] - mc);
        var asc = VedicMath.Normalize(cusps[0] - mc);

        Assert.True(cusp11 < cusp12, $"cusp11-mc={cusp11:F3} should be < cusp12-mc={cusp12:F3} (both should sit between MC={mc:F3} and ASC-mc={asc:F3})");
        Assert.True(cusp12 < asc, $"cusp12-mc={cusp12:F3} should be < asc-mc={asc:F3}");
    }

    // Symmetric check to the MC/11/12/ASC test above: houses 2 and 3 sit
    // between the Ascendant and the IC, with house 2 (adjacent to ASC)
    // closer to the Ascendant and house 3 (adjacent to IC) closer to the IC.
    [Fact]
    public void Cusps_2And3_FallBetweenAscendantAndICInOrder()
    {
        var time = new AstroTime(new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc));
        var cusps = _calculator.Cusps(time, 19.0760, 72.8777);

        var asc = cusps[0];
        var cusp2 = VedicMath.Normalize(cusps[1] - asc);
        var cusp3 = VedicMath.Normalize(cusps[2] - asc);
        var ic = VedicMath.Normalize(cusps[3] - asc);

        Assert.True(cusp2 < cusp3, $"cusp2-asc={cusp2:F3} should be < cusp3-asc={cusp3:F3} (both should sit between ASC and IC-asc={ic:F3})");
        Assert.True(cusp3 < ic, $"cusp3-asc={cusp3:F3} should be < ic-asc={ic:F3}");
    }
}

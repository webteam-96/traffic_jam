using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class AstroEngineServiceTests
{
    private static AstroEngineService BuildService() =>
        new(new LahiriAyanamsaService(), new AscendantCalculator());

    [Fact]
    public void ComputeBirthChart_TimeKnown_ReturnsAllNinePlanetsWithHousesAndAscendant()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        Assert.Equal(9, chart.D1.Count);
        Assert.Contains(chart.D1, p => p.Planet == "Sun");
        Assert.Contains(chart.D1, p => p.Planet == "Rahu");
        Assert.Contains(chart.D1, p => p.Planet == "Ketu");
        Assert.All(chart.D1, p => Assert.NotNull(p.House));
        Assert.All(chart.D1, p => Assert.InRange(p.House!.Value, 1, 12));
        Assert.NotNull(chart.AscendantSignIndex);
        Assert.InRange(chart.AscendantSignIndex!.Value, 0, 11);
    }

    [Fact]
    public void ComputeBirthChart_TimeUnknown_SkipsAscendantAndHousesButKeepsSigns()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 12, 0, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: false);

        Assert.Equal(9, chart.D1.Count);
        Assert.All(chart.D1, p => Assert.Null(p.House));
        Assert.All(chart.D1, p => Assert.InRange(p.SignIndex, 0, 11)); // signs are still real

        // The bug this regression test guards against: AscendantSignIndex (and
        // the two longitude fields) used to silently default to 0 (Aries) via
        // `?? 0` when the birth time was unknown, instead of honestly
        // reporting "unknown" — see AstroModels.cs's BirthChartResult doc comment.
        Assert.Null(chart.AscendantSignIndex);
        Assert.Null(chart.AscendantTropicalLongitude);
        Assert.Null(chart.AscendantSiderealLongitude);
    }

    [Fact]
    public void ComputeBirthChart_MoonNakshatra_MatchesMoonsSiderealLongitude()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        var moon = chart.D1.Single(p => p.Planet == "Moon");
        var (expectedIndex, _) = VedicMath.Nakshatra(moon.SignIndex * 30.0 + moon.DegreeInSign);

        Assert.Equal(VedicMath.NakshatraNames[expectedIndex], chart.MoonNakshatra.Name);
    }

    [Fact]
    public void ComputeBirthChart_RahuAndKetu_AreAlwaysExactlyOpposite()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(2026, 8, 31, 0, 0, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        var rahu = chart.D1.Single(p => p.Planet == "Rahu");
        var ketu = chart.D1.Single(p => p.Planet == "Ketu");
        var rahuLon = rahu.SignIndex * 30.0 + rahu.DegreeInSign;
        var ketuLon = ketu.SignIndex * 30.0 + ketu.DegreeInSign;

        Assert.Equal(180.0, VedicMath.Normalize(ketuLon - rahuLon), precision: 6);
    }

    [Fact]
    public void ComputeBirthChart_MoonChart_UsesMoonSignAsHouseOne()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        var moon = chart.MoonChart.Single(p => p.Planet == "Moon");
        Assert.Equal(1, moon.House); // the Moon is always house 1 of its own chart
    }

    [Fact]
    public void ComputeBirthChart_TimeKnown_ReturnsD10AndD60ForAllNinePlanets()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        Assert.Equal(9, chart.D10.Count);
        Assert.NotNull(chart.D60);
        Assert.Equal(9, chart.D60!.Count);
        Assert.All(chart.D10, p => Assert.InRange(p.SignIndex, 0, 11));
        Assert.All(chart.D60, p => Assert.InRange(p.SignIndex, 0, 11));
    }

    [Fact]
    public void ComputeBirthChart_TimeUnknown_D10StillComputed_ButD60IsNull()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 12, 0, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: false);

        Assert.Equal(9, chart.D10.Count); // D10's 3° slices are wide enough to not need exact time
        Assert.Null(chart.D60); // D60's 0°30' slices are too narrow for an approximate time — see doc comment
    }

    [Fact]
    public void ComputeBirthChart_TimeKnown_EachVargaHasItsOwnLagnaAndEveryPlanetHasAHouse()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        Assert.NotNull(chart.D9AscendantSignIndex);
        Assert.NotNull(chart.D10AscendantSignIndex);
        Assert.NotNull(chart.D60AscendantSignIndex);
        Assert.InRange(chart.D9AscendantSignIndex!.Value, 0, 11);
        Assert.InRange(chart.D10AscendantSignIndex!.Value, 0, 11);
        Assert.InRange(chart.D60AscendantSignIndex!.Value, 0, 11);

        Assert.All(chart.D9, p => Assert.NotNull(p.House));
        Assert.All(chart.D10, p => Assert.NotNull(p.House));
        Assert.All(chart.D60!, p => Assert.NotNull(p.House));
        Assert.All(chart.D9, p => Assert.InRange(p.House!.Value, 1, 12));

        // Every planet's house must agree with HouseFromSign(planet sign, varga Lagna).
        foreach (var p in chart.D9)
        {
            Assert.Equal(((p.SignIndex - chart.D9AscendantSignIndex!.Value + 12) % 12) + 1, p.House);
        }
    }

    [Fact]
    public void ComputeBirthChart_TimeUnknown_VargaAscendantsAndHousesAreNull()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 12, 0, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: false);

        Assert.Null(chart.D9AscendantSignIndex);
        Assert.Null(chart.D10AscendantSignIndex);
        Assert.Null(chart.D60AscendantSignIndex);
        Assert.All(chart.D9, p => Assert.Null(p.House));
        Assert.All(chart.D10, p => Assert.Null(p.House));
    }

    [Fact]
    public void ComputeBirthChart_D10AndD60_MatchTheStandaloneVedicMathFormulas()
    {
        var service = BuildService();

        var chart = service.ComputeBirthChart(
            new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc), 19.0760, 72.8777, timeKnown: true);

        foreach (var planet in chart.D1)
        {
            var sidereal = planet.SignIndex * 30.0 + planet.DegreeInSign;
            var expectedD10Sign = VedicMath.DashamshaSignIndex(sidereal);
            var expectedD60Sign = VedicMath.ShastiamshaSignIndex(sidereal);

            Assert.Equal(expectedD10Sign, chart.D10.Single(p => p.Planet == planet.Planet).SignIndex);
            Assert.Equal(expectedD60Sign, chart.D60!.Single(p => p.Planet == planet.Planet).SignIndex);
        }
    }
}

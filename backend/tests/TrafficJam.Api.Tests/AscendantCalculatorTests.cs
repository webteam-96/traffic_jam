using CosineKitty;
using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class AscendantCalculatorTests
{
    // The Ascendant is, by definition, "whatever ecliptic point is on the
    // eastern horizon right now." At the exact moment of sunrise, the Sun
    // itself is that point — the Sun is on the ecliptic (latitude ~0) and,
    // by definition of sunrise, on the horizon and rising. So the Ascendant
    // computed here should land very close to the Sun's own tropical
    // longitude at that moment. This validates the whole rotation/root-find
    // pipeline against a real geometric fact instead of a hand-derived
    // "expected" number, which is what actually needs independent checking.
    [Theory]
    [InlineData(19.0760, 72.8777)]   // Mumbai
    [InlineData(28.6139, 77.2090)]   // Delhi
    [InlineData(-33.8688, 151.2093)] // Sydney (southern hemisphere)
    [InlineData(51.5072, -0.1276)]   // London (western longitude, shallow ecliptic-horizon angle)
    public void TropicalAscendant_AtSunrise_IsCloseToTheSunsOwnLongitude(double lat, double lng)
    {
        var observer = new Observer(lat, lng, 0);
        var startTime = new AstroTime(new DateTime(2026, 3, 20, 0, 0, 0, DateTimeKind.Utc)); // near equinox, avoids polar edge cases
        var sunrise = GeometricSunrise(observer, startTime);

        var calculator = new AscendantCalculator();
        var ascendant = calculator.TropicalAscendant(sunrise, lat, lng);
        var sunLongitude = Astronomy.SunPosition(sunrise).elon;

        var diff = Math.Abs(VedicMath.Normalize(ascendant) - VedicMath.Normalize(sunLongitude));
        diff = Math.Min(diff, 360 - diff);

        // Tight tolerance: both sides now use the same no-refraction convention,
        // so this should agree to well under a tenth of a degree, not just
        // "roughly the same part of the sky."
        Assert.True(diff < 0.1, $"Ascendant {ascendant:F4}° vs Sun {sunLongitude:F4}° at sunrise — diff {diff:F4}°");
    }

    /// <summary>
    /// SearchRiseSet bakes in a fixed 34' refraction + solar semi-diameter
    /// correction that AscendantCalculator (deliberately, to match a plain
    /// geometric horizon) does not use — comparing across that mismatch
    /// produced a latitude-dependent few-degree gap (worse at shallow
    /// ecliptic-horizon angles, e.g. London) that had nothing to do with
    /// correctness. This finds the true geometric (Refraction.None) moment
    /// the Sun's center crosses the horizon, so both sides of the test use
    /// an identical convention.
    /// </summary>
    private static AstroTime GeometricSunrise(Observer observer, AstroTime startTime)
    {
        var refractedRise = Astronomy.SearchRiseSet(Body.Sun, observer, Direction.Rise, startTime, 2, 0);
        Assert.NotNull(refractedRise);

        double Altitude(AstroTime t)
        {
            var eq = Astronomy.Equator(Body.Sun, t, observer, EquatorEpoch.OfDate, Aberration.Corrected);
            return Astronomy.Horizon(t, observer, eq.ra, eq.dec, Refraction.None).altitude;
        }

        // Geometric center-crossing happens slightly after the refraction-
        // corrected "first appears" moment, so bracket forward a few minutes.
        var lo = refractedRise!.AddDays(-5.0 / 1440.0);
        var hi = refractedRise.AddDays(10.0 / 1440.0);
        var loAlt = Altitude(lo);
        for (var i = 0; i < 40; i++)
        {
            var mid = lo.AddDays((hi.ut - lo.ut) / 2.0);
            var midAlt = Altitude(mid);
            if (Math.Sign(midAlt) == Math.Sign(loAlt)) { lo = mid; loAlt = midAlt; }
            else { hi = mid; }
        }

        return lo.AddDays((hi.ut - lo.ut) / 2.0);
    }

    [Fact]
    public void TropicalAscendant_ReturnsValueInValidRange()
    {
        var calculator = new AscendantCalculator();
        var time = new AstroTime(new DateTime(1988, 10, 24, 4, 42, 0, DateTimeKind.Utc));

        var ascendant = calculator.TropicalAscendant(time, 19.0760, 72.8777);

        Assert.InRange(ascendant, 0.0, 360.0);
    }
}

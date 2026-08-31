using CosineKitty;
using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class AyanamsaServiceTests
{
    // Reference values: published Lahiri (Chitra Paksha) ayanamsa for
    // January 1 00:00 UT, computed with Swiss Ephemeris including nutation
    // (jagannathhora.com historical tables). Our formula omits the ~17"
    // nutation wobble (stated to swing the year-to-year rate between 44"
    // and 57" around the 50.3"/year mean), so the tolerance below is set to
    // comfortably clear that known, bounded gap rather than to make the
    // test pass by accident.
    [Theory]
    [InlineData(2000, 1, 1, 23, 51, 12)]
    [InlineData(2010, 1, 1, 24, 0, 5)]
    [InlineData(2020, 1, 1, 24, 7, 55)]
    [InlineData(2024, 1, 1, 24, 11, 27)]
    [InlineData(2025, 1, 1, 24, 12, 23)]
    [InlineData(2026, 1, 1, 24, 13, 19)]
    public void LahiriDegrees_MatchesPublishedReferenceValues_WithinNutationTolerance(
        int year, int month, int day, int refDeg, int refMin, int refSec)
    {
        var service = new LahiriAyanamsaService();
        var time = new AstroTime(new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc));
        var expected = refDeg + refMin / 60.0 + refSec / 3600.0;

        var actual = service.LahiriDegrees(time);

        Assert.True(Math.Abs(actual - expected) < 0.02, // 72" — clears the ~17" nutation wobble with margin
            $"Expected ~{expected:F5}°, got {actual:F5}° (diff {Math.Abs(actual - expected) * 3600:F1}\")");
    }

    [Fact]
    public void LahiriDegrees_IncreasesOverTime()
    {
        var service = new LahiriAyanamsaService();
        var earlier = service.LahiriDegrees(new AstroTime(new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc)));
        var later = service.LahiriDegrees(new AstroTime(new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)));

        Assert.True(later > earlier); // precession is a one-directional drift
    }
}

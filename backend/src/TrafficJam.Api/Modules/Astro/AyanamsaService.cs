using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public interface IAyanamsaService
{
    /// <summary>The Lahiri (Chitra Paksha) ayanamsa, in degrees, at the given moment.</summary>
    double LahiriDegrees(AstroTime time);
}

/// <summary>
/// Computes the Lahiri ayanamsa — the offset between the tropical zodiac
/// (what Astronomy Engine outputs) and the sidereal zodiac Vedic astrology
/// uses. Swiss Ephemeris has this built in as a flag; without it, this is
/// the one calculation we own directly.
///
/// Formula: an empirical anchor at J2000.0 (23°51'12", matching published
/// Lahiri reference tables for 2000-01-01) plus the IAU general-precession-
/// in-longitude series accumulated from J2000. This omits the ~17"-amplitude,
/// 18.6-year nutation wobble that full ephemeris-grade ayanamsa includes —
/// verified against published reference values for 2000/2010/2020/2024-2026,
/// the largest residual was ~19" (see AyanamsaServiceTests), which is well
/// inside Astronomy Engine's own ~1-arcminute (60") position accuracy, so it
/// isn't the limiting factor on overall chart precision.
/// </summary>
public class LahiriAyanamsaService : IAyanamsaService
{
    private const double AnchorDegreesAtJ2000 = 23.0 + 51.0 / 60.0 + 12.0 / 3600.0;

    public double LahiriDegrees(AstroTime time)
    {
        var t = time.tt / 36525.0; // Julian centuries since J2000.0 (TT)

        var precessionArcsec =
            5028.796195 * t
            + 1.1054348 * t * t
            + 0.00007964 * t * t * t
            - 0.000023857 * t * t * t * t;

        return AnchorDegreesAtJ2000 + precessionArcsec / 3600.0;
    }
}

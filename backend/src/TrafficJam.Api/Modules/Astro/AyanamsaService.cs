using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public interface IAyanamsaService
{
    /// <summary>The Lahiri (Chitra Paksha) ayanamsa, in degrees, at the given moment.</summary>
    double LahiriDegrees(AstroTime time);

    /// <summary>
    /// The Krishnamurti (KP) ayanamsa, in degrees. Used only by the KP
    /// System/Cusp Chart — see <see cref="LahiriAyanamsaService.KpDegrees"/>
    /// for why KP can't just borrow Lahiri's.
    /// </summary>
    double KpDegrees(AstroTime time);
}

/// <summary>
/// Computes the ayanamsa — the offset between the tropical zodiac (what
/// Astronomy Engine outputs) and the sidereal zodiac Vedic astrology uses.
/// Swiss Ephemeris has these built in as flags; without it, this is the one
/// calculation we own directly.
///
/// Both variants are the same IAU general-precession-in-longitude series
/// (<see cref="PrecessionArcsec"/>) accumulated from an empirical anchor —
/// they differ only in where that anchor sits and what value it takes. The
/// series omits the ~17"-amplitude, 18.6-year nutation wobble that full
/// ephemeris-grade ayanamsa includes — verified against published Lahiri
/// reference values for 2000/2010/2020/2024-2026, the largest residual was
/// ~19" (see AyanamsaServiceTests), which is well inside Astronomy Engine's
/// own ~1-arcminute (60") position accuracy, so it isn't the limiting factor
/// on overall chart precision.
/// </summary>
public class LahiriAyanamsaService : IAyanamsaService
{
    private const double LahiriAnchorDegreesAtJ2000 = 23.0 + 51.0 / 60.0 + 12.0 / 3600.0;

    /// <summary>
    /// Krishnamurti's anchor: 22°21'50" at J1900 (JD 2415020.0), the value
    /// Swiss Ephemeris uses for SE_SIDM_KRISHNAMURTI and therefore the one
    /// virtually every KP tool agrees on.
    /// </summary>
    private const double KpAnchorDegreesAtJ1900 = 22.0 + 21.0 / 60.0 + 50.0 / 3600.0;

    /// <summary>
    /// J1900 expressed in the same units <see cref="PrecessionArcsec"/> takes:
    /// Julian centuries from J2000. JD 2415020.0 is exactly one Julian century
    /// before JD 2451545.0, so this is exactly -1 — no rounding involved.
    /// </summary>
    private const double J1900InCenturiesFromJ2000 = -1.0;

    public double LahiriDegrees(AstroTime time) =>
        LahiriAnchorDegreesAtJ2000 + PrecessionArcsec(CenturiesFromJ2000(time)) / 3600.0;

    /// <summary>
    /// KP astrology uses Krishnamurti's own ayanamsa, not Lahiri. The gap is
    /// small — about 5.5 arcminutes — but it matters far more here than the
    /// number suggests, because KP subdivides the zodiac much more finely than
    /// anything else in this app: the narrowest sub spans 40 arcminutes and
    /// the narrowest sub-sub just 2. A 5.5' shift is therefore wider than an
    /// entire smallest sub-sub division, so using Lahiri would put sub-sub
    /// lords routinely wrong and sub lords wrong near any boundary — and KP
    /// treats the sub lord as the deciding factor for a house.
    ///
    /// Anchored at J1900 rather than J2000 because that's where Krishnamurti's
    /// published value is defined; the precession accumulated between the two
    /// epochs is subtracted so the same series can be reused.
    /// </summary>
    public double KpDegrees(AstroTime time) =>
        KpAnchorDegreesAtJ1900
        + (PrecessionArcsec(CenturiesFromJ2000(time))
           - PrecessionArcsec(J1900InCenturiesFromJ2000)) / 3600.0;

    private static double CenturiesFromJ2000(AstroTime time) => time.tt / 36525.0;

    /// <summary>General precession in longitude, arcseconds, accumulated from J2000.</summary>
    private static double PrecessionArcsec(double t) =>
        5028.796195 * t
        + 1.1054348 * t * t
        + 0.00007964 * t * t * t
        - 0.000023857 * t * t * t * t;
}

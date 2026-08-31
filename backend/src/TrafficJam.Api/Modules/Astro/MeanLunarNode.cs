using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// Rahu/Ketu aren't physical bodies — no library exposes a "position" for
/// them directly — so this is the standard, public-domain Meeus formula for
/// the Moon's mean ascending node, the same computation Swiss-Ephemeris-based
/// software uses under the hood for "Mean Node" mode.
/// </summary>
public static class MeanLunarNode
{
    /// <summary>Tropical longitude of Rahu (mean ascending node), in degrees.</summary>
    public static double RahuTropicalLongitude(AstroTime time)
    {
        var t = time.tt / 36525.0;
        var omega = 125.0445479
            - 1934.1362891 * t
            + 0.0020754 * t * t
            + t * t * t / 467441.0
            - t * t * t * t / 60616000.0;
        return VedicMath.Normalize(omega);
    }

    /// <summary>Tropical longitude of Ketu (mean descending node) — always exactly opposite Rahu.</summary>
    public static double KetuTropicalLongitude(AstroTime time) =>
        VedicMath.Normalize(RahuTropicalLongitude(time) + 180.0);
}

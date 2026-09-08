using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public record GrahaPosition(string Name, double SiderealLongitude, bool Retrograde);

/// <summary>
/// Sidereal longitude + retrograde state for all 9 classical grahas (Surya
/// ... Ketu) at a given moment — the one primitive both birth-chart
/// generation (AstroEngineService) and daily transits (TransitService) are
/// built on, evaluated once for birth and once daily for "now" respectively.
/// Pulled out here once a second consumer needed the exact same block.
/// </summary>
public static class GrahaPositions
{
    private static readonly Body[] EphemerisPlanets =
    [
        Body.Mercury, Body.Venus, Body.Mars, Body.Jupiter, Body.Saturn,
    ];

    /// <summary>
    /// Uranus, Neptune and Pluto. Not grahas — classical Vedic astrology
    /// predates their discovery and every rule in this app (dignity, dasha,
    /// dosha, house lordship, transits) is defined over the nine only. They're
    /// therefore opt-in, and used solely to fill the KP table's outer-planet
    /// rows; adding them to the birth chart proper would silently change
    /// results that are supposed to be classical.
    /// </summary>
    private static readonly Body[] OuterPlanets = [Body.Uranus, Body.Neptune, Body.Pluto];

    /// <summary>Slow-moving grahas — meaningful over weeks/months, the ones classical "major transit" tracking (e.g. Sade Sati) follows. The rest move too fast day-to-day to carry that kind of predictive weight.</summary>
    public static readonly HashSet<string> MajorTransitPlanets = ["Jupiter", "Saturn", "Rahu", "Ketu"];

    public static List<GrahaPosition> ComputeAll(AstroTime time, IAyanamsaService ayanamsa) =>
        ComputeAll(time, ayanamsa.LahiriDegrees(time));

    /// <summary>
    /// Same positions against a caller-chosen ayanamsa. KP needs this: it uses
    /// the Krishnamurti ayanamsa rather than Lahiri, and its planets and its
    /// house cusps must be measured against the same one or the lordship
    /// chains won't line up with the cusps they're read against.
    /// </summary>
    public static List<GrahaPosition> ComputeAll(
        AstroTime time, double ayanamsaDeg, bool includeOuterPlanets = false)
    {
        var result = new List<GrahaPosition>
        {
            new("Sun", VedicMath.Normalize(Astronomy.SunPosition(time).elon - ayanamsaDeg), false),
            new("Moon", VedicMath.Normalize(Astronomy.EclipticGeoMoon(time).lon - ayanamsaDeg), false),
        };

        foreach (var body in EphemerisPlanets)
        {
            var sidereal = VedicMath.Normalize(TropicalLongitude(body, time) - ayanamsaDeg);
            result.Add(new GrahaPosition(body.ToString(), sidereal, IsRetrograde(body, time)));
        }

        if (includeOuterPlanets)
        {
            foreach (var body in OuterPlanets)
            {
                var sidereal = VedicMath.Normalize(TropicalLongitude(body, time) - ayanamsaDeg);
                result.Add(new GrahaPosition(body.ToString(), sidereal, IsRetrograde(body, time)));
            }
        }

        result.Add(new GrahaPosition("Rahu", VedicMath.Normalize(MeanLunarNode.RahuTropicalLongitude(time) - ayanamsaDeg), true));
        result.Add(new GrahaPosition("Ketu", VedicMath.Normalize(MeanLunarNode.KetuTropicalLongitude(time) - ayanamsaDeg), true));

        return result;
    }

    public static double TropicalLongitude(Body body, AstroTime time)
    {
        var vector = Astronomy.GeoVector(body, time, Aberration.Corrected);
        return Astronomy.EquatorialToEcliptic(vector).elon;
    }

    public static bool IsRetrograde(Body body, AstroTime time)
    {
        const double halfDay = 0.5;
        var before = TropicalLongitude(body, time.AddDays(-halfDay));
        var after = TropicalLongitude(body, time.AddDays(halfDay));
        var delta = after - before;
        if (delta > 180) delta -= 360;
        if (delta < -180) delta += 360;
        return delta < 0;
    }
}

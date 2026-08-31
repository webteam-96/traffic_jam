using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public record TransitPlanet(
    string Planet, int SignIndex, string Sign, double DegreeInSign, bool Retrograde, bool IsMajor,
    int? HouseFromLagna, int HouseFromMoon);

public record TransitResult(DateOnly Date, IReadOnlyList<TransitPlanet> Planets);

public interface ITransitService
{
    /// <summary>
    /// Computes today's Gochar — where each graha currently sits relative to
    /// a user's own natal Lagna and Moon sign. <paramref name="natalLagnaSignIndex"/>
    /// is null for users with an unknown birth time (no Lagna could be
    /// computed — see AstroEngineService), in which case HouseFromLagna comes
    /// back null too rather than a wrong guess; HouseFromMoon is unaffected
    /// since the Moon's sign doesn't need exact birth time.
    /// </summary>
    TransitResult Compute(DateOnly date, int? natalLagnaSignIndex, int natalMoonSignIndex);
}

/// <summary>
/// Daily transits (Gochar) — not a new calculation, GrahaPositions.ComputeAll
/// re-evaluated for "now" instead of birth, then placed into whole-sign
/// houses counted from the user's own natal Lagna and Moon (BACKEND_REQUIREMENTS.md:
/// "current planet positions mapped against each user's Moon & Lagna").
/// Evaluated at a fixed UTC-noon reference for the date — unlike Panchang,
/// which needs a real sunrise/sunset for its location-specific day boundary,
/// a graha's *sign* is stable enough across a single day (bar the Moon, at
/// ~13°/day) that this doesn't need per-user location/timezone precision.
/// </summary>
public class TransitService(IAyanamsaService ayanamsa) : ITransitService
{
    public TransitResult Compute(DateOnly date, int? natalLagnaSignIndex, int natalMoonSignIndex)
    {
        var time = new AstroTime(date.ToDateTime(new TimeOnly(12, 0), DateTimeKind.Utc));

        var planets = GrahaPositions.ComputeAll(time, ayanamsa)
            .Select(g =>
            {
                var signIndex = VedicMath.SignIndex(g.SiderealLongitude);
                return new TransitPlanet(
                    g.Name, signIndex, VedicMath.SignNames[signIndex], VedicMath.DegreeInSign(g.SiderealLongitude),
                    g.Retrograde, GrahaPositions.MajorTransitPlanets.Contains(g.Name),
                    natalLagnaSignIndex is null ? null : VedicMath.HouseFromSign(signIndex, natalLagnaSignIndex.Value),
                    VedicMath.HouseFromSign(signIndex, natalMoonSignIndex));
            })
            .ToList();

        return new TransitResult(date, planets);
    }
}

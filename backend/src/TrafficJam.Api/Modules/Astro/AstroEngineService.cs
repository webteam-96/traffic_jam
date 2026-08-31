using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public interface IAstroEngineService
{
    /// <summary>
    /// Computes a birth chart. <paramref name="timeKnown"/> false means the
    /// exact time of birth wasn't captured (mirrors BirthData.UnknownTime) —
    /// planet signs/Nakshatra are still meaningful (they barely move across a
    /// single day), but the Ascendant and house placement genuinely require
    /// the real clock time, so those come back null rather than a wrong guess.
    /// D60 additionally comes back null in this case even though it doesn't
    /// use the Ascendant at all — a 0°30' D60 slice is so narrow that even
    /// the Moon's ordinary daily motion crosses one roughly every 40 minutes,
    /// so an approximate (e.g. noon-default) birth time would silently
    /// produce a specific-looking but essentially arbitrary D60 result. D9
    /// and D10's much wider slices (3°20' and 3°) don't have this problem.
    /// </summary>
    BirthChartResult ComputeBirthChart(DateTime birthUtc, double latitude, double longitude, bool timeKnown);
}

/// <summary>
/// Astro Engine, built on Astronomy Engine (MIT license) rather than Swiss
/// Ephemeris — see backend/README.md "Astro Engine" for why. Produces the
/// birth chart as BACKEND_REQUIREMENTS.md defines it: Lagna, the 9 classical
/// planets (Surya...Ketu) with house placement, Navamsha (D9), Nakshatra —
/// plus the Moon chart (Chandra Kundli, houses-from-a-sign logic reused with
/// the Moon's sign as house 1 instead of the Ascendant's) and the Kundli-
/// expansion divisional charts D10 (Dashamsha) and D60 (Shashtiamsha) — see
/// VedicMath.cs for each chart's formula and, for D60 specifically, the note
/// on which of several genuinely-disputed classical conventions this uses.
///
/// Deliberately NOT built yet, as a separate follow-up: KP sub-lords/Cusp
/// chart (added later for the Kundli expansion — see Chart.cs). That's its
/// own well-scoped formula on top of this same sidereal-longitude
/// foundation, not a new engine.
/// </summary>
public class AstroEngineService(IAyanamsaService ayanamsa, IAscendantCalculator ascendant) : IAstroEngineService
{
    public BirthChartResult ComputeBirthChart(DateTime birthUtc, double latitude, double longitude, bool timeKnown)
    {
        var time = new AstroTime(birthUtc);
        var ayanamsaDeg = ayanamsa.LahiriDegrees(time);
        var siderealByPlanet = GrahaPositions.ComputeAll(time, ayanamsa)
            .Select(g => (g.Name, Longitude: g.SiderealLongitude, g.Retrograde))
            .ToList();
        var moonSidereal = siderealByPlanet.Single(p => p.Name == "Moon").Longitude;

        double? ascendantTropical = null;
        double? ascendantSidereal = null;
        int? ascendantSign = null;
        if (timeKnown)
        {
            ascendantTropical = ascendant.TropicalAscendant(time, latitude, longitude);
            ascendantSidereal = VedicMath.Normalize(ascendantTropical.Value - ayanamsaDeg);
            ascendantSign = VedicMath.SignIndex(ascendantSidereal.Value);
        }

        var d1 = siderealByPlanet
            .Select(p => ToPlanetPosition(p.Name, p.Longitude, p.Retrograde, ascendantSign))
            .ToList();

        var d9 = siderealByPlanet
            .Select(p => ToDivisionalPosition(p.Name, p.Longitude, p.Retrograde, VedicMath.NavamshaSignIndex, VedicMath.NavamshaDegreeInSign))
            .ToList();

        var d10 = siderealByPlanet
            .Select(p => ToDivisionalPosition(p.Name, p.Longitude, p.Retrograde, VedicMath.DashamshaSignIndex, VedicMath.DashamshaDegreeInSign))
            .ToList();

        var d60 = timeKnown
            ? siderealByPlanet
                .Select(p => ToDivisionalPosition(p.Name, p.Longitude, p.Retrograde, VedicMath.ShastiamshaSignIndex, VedicMath.ShastiamshaDegreeInSign))
                .ToList()
            : null;

        var moonSign = VedicMath.SignIndex(moonSidereal);
        var moonChart = siderealByPlanet
            .Select(p => ToPlanetPosition(p.Name, p.Longitude, p.Retrograde, moonSign))
            .ToList();

        var (nakshatraIndex, pada) = VedicMath.Nakshatra(moonSidereal);

        return new BirthChartResult(
            ayanamsaDeg,
            ascendantTropical ?? 0,
            ascendantSidereal ?? 0,
            ascendantSign ?? 0,
            d1,
            d9,
            d10,
            d60,
            moonChart,
            new NakshatraInfo(VedicMath.NakshatraNames[nakshatraIndex], nakshatraIndex, pada));
    }

    private static PlanetPosition ToPlanetPosition(string name, double siderealLongitude, bool retrograde, int? ascendantSign)
    {
        var signIndex = VedicMath.SignIndex(siderealLongitude);
        int? house = ascendantSign is null ? null : VedicMath.HouseFromSign(signIndex, ascendantSign.Value);
        return new PlanetPosition(name, signIndex, VedicMath.SignNames[signIndex], VedicMath.DegreeInSign(siderealLongitude), house, retrograde);
    }

    private static PlanetPosition ToDivisionalPosition(
        string name, double siderealLongitude, bool retrograde,
        Func<double, int> signIndexFn, Func<double, double> degreeInSignFn)
    {
        var signIndex = signIndexFn(siderealLongitude);
        return new PlanetPosition(name, signIndex, VedicMath.SignNames[signIndex], degreeInSignFn(siderealLongitude), null, retrograde);
    }
}

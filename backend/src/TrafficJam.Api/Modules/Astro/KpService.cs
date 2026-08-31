using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public record KpPlanetInfo(string Planet, int SignIndex, string Sign, double DegreeInSign, KpLordship Lordship, int House);
public record KpCuspInfo(int House, int SignIndex, string Sign, double DegreeInSign, KpLordship Lordship, IReadOnlyList<string> Planets);
public record KpChartResult(IReadOnlyList<KpPlanetInfo> Planets, IReadOnlyList<KpCuspInfo> Cusps);

public interface IKpService
{
    /// <summary>
    /// Computes the KP System tab (each planet's sign/star/sub/sub-sub lord,
    /// placed into its real Placidus house) and the Cusp Chart tab (each of
    /// the 12 cusps' degree, sign, lordship chain, and which planets fall in
    /// that house). Needs a genuinely exact birth time — there is no
    /// meaningful Placidus chart without one, same reasoning as D60 (see
    /// AstroEngineService), so this is only ever called when timeKnown.
    /// </summary>
    KpChartResult Compute(AstroTime time, double latitude, double longitude, IReadOnlyList<PlanetPosition> d1Planets);
}

/// <summary>
/// KP System + Cusp Chart — the last two pieces of BACKEND_REQUIREMENTS.md's
/// Kundli expansion. Not a new astronomy calculation on top of the birth
/// chart's own planet positions (KpLordship.cs's sign/star/sub/sub-sub chain
/// is pure degree arithmetic on longitudes AstroEngineService already
/// computed) — the one genuinely new piece here is the Placidus house cusps
/// (PlacidusHouseCalculator.cs), since KP uses that house system rather than
/// the whole-sign houses used everywhere else in this app.
/// </summary>
public class KpService(IPlacidusHouseCalculator placidus, IAyanamsaService ayanamsa) : IKpService
{
    public KpChartResult Compute(AstroTime time, double latitude, double longitude, IReadOnlyList<PlanetPosition> d1Planets)
    {
        var ayanamsaDeg = ayanamsa.LahiriDegrees(time);
        var tropicalCusps = placidus.Cusps(time, latitude, longitude);
        var siderealCusps = tropicalCusps.Select(c => VedicMath.Normalize(c - ayanamsaDeg)).ToArray();

        var planetHouses = d1Planets.ToDictionary(
            p => p.Planet,
            p => HouseFromCusps(p.SignIndex * 30.0 + p.DegreeInSign, siderealCusps));

        var planets = d1Planets
            .Select(p => new KpPlanetInfo(
                p.Planet, p.SignIndex, p.Sign, p.DegreeInSign,
                KpLordshipCalculator.Compute(p.SignIndex * 30.0 + p.DegreeInSign),
                planetHouses[p.Planet]))
            .ToList();

        var cusps = new List<KpCuspInfo>(12);
        for (var i = 0; i < 12; i++)
        {
            var house = i + 1;
            var signIndex = VedicMath.SignIndex(siderealCusps[i]);
            var planetsHere = planetHouses.Where(kv => kv.Value == house).Select(kv => kv.Key).ToList();
            cusps.Add(new KpCuspInfo(
                house, signIndex, VedicMath.SignNames[signIndex], VedicMath.DegreeInSign(siderealCusps[i]),
                KpLordshipCalculator.Compute(siderealCusps[i]), planetsHere));
        }

        return new KpChartResult(planets, cusps);
    }

    /// <summary>
    /// Which of the 12 (generally unequal-width) Placidus houses a longitude
    /// falls in — house N spans from cusp[N-1] forward to cusp[N mod 12].
    /// "Forward" is measured as an angular offset so it's wraparound-safe
    /// (a house that straddles 360°/0° works the same as any other).
    /// </summary>
    private static int HouseFromCusps(double longitude, double[] siderealCusps)
    {
        for (var house = 1; house <= 12; house++)
        {
            var start = siderealCusps[house - 1];
            var end = siderealCusps[house % 12];
            var span = VedicMath.Normalize(end - start);
            var offset = VedicMath.Normalize(longitude - start);
            if (offset < span) return house;
        }

        throw new InvalidOperationException("A longitude must fall in exactly one of the 12 cusp spans — unreachable if the cusps are well-formed.");
    }
}

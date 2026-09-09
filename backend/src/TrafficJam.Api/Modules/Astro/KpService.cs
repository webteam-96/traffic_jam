using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public record KpPlanetInfo(
    string Planet, int SignIndex, string Sign, double DegreeInSign,
    KpLordship Lordship, int House, bool Retrograde);
public record KpCuspInfo(int House, int SignIndex, string Sign, double DegreeInSign, KpLordship Lordship, IReadOnlyList<string> Planets);
public record KpChartResult(
    IReadOnlyList<KpPlanetInfo> Planets,
    IReadOnlyList<KpCuspInfo> Cusps,
    IReadOnlyList<KpSignificatorInfo> Significators);

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
    KpChartResult Compute(AstroTime time, double latitude, double longitude);
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
    public KpChartResult Compute(AstroTime time, double latitude, double longitude)
    {
        // The KP ayanamsa, not Lahiri — and applied to the planets as well as
        // the cusps. Positions and cusps have to share one zero point: a
        // planet's lordship chain is read against the cusp it sits behind, so
        // measuring the two from offsets 5.5' apart would misplace planets
        // near a cusp and make the two tables quietly disagree.
        var ayanamsaDeg = ayanamsa.KpDegrees(time);
        var tropicalCusps = placidus.Cusps(time, latitude, longitude);
        var siderealCusps = tropicalCusps.Select(c => VedicMath.Normalize(c - ayanamsaDeg)).ToArray();

        // Uranus/Neptune/Pluto are included here and nowhere else — KP tables
        // conventionally list them, while every classical rule in this app is
        // defined over the nine grahas alone.
        var grahas = GrahaPositions.ComputeAll(time, ayanamsaDeg, includeOuterPlanets: true);

        var planets = grahas
            .Select(g =>
            {
                var signIndex = VedicMath.SignIndex(g.SiderealLongitude);
                return new KpPlanetInfo(
                    g.Name, signIndex, VedicMath.SignNames[signIndex],
                    VedicMath.DegreeInSign(g.SiderealLongitude),
                    KpLordshipCalculator.Compute(g.SiderealLongitude),
                    HouseFromCusps(g.SiderealLongitude, siderealCusps),
                    g.Retrograde);
            })
            .ToList();

        var planetHouses = planets.ToDictionary(p => p.Planet, p => p.House);

        // Every KP planets table opens with the Ascendant, because its own
        // lordship chain is read exactly like a planet's. In Placidus the
        // Ascendant *is* cusp 1, so it's taken from there rather than
        // recomputed — the two must agree, and deriving it guarantees they do.
        var ascLongitude = siderealCusps[0];
        var ascSignIndex = VedicMath.SignIndex(ascLongitude);
        planets.Insert(0, new KpPlanetInfo(
            "Ascendant", ascSignIndex, VedicMath.SignNames[ascSignIndex],
            VedicMath.DegreeInSign(ascLongitude),
            KpLordshipCalculator.Compute(ascLongitude), House: 1, Retrograde: false));

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

        return new KpChartResult(
            planets, cusps, KpSignificatorCalculator.Compute(planets, cusps));
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

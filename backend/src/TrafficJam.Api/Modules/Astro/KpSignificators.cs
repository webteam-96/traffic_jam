namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// One planet's KP significator houses, in KP's four strength levels.
/// Each list holds house numbers 1..12, ascending, with no duplicates.
/// </summary>
public record KpSignificatorInfo(
    string Planet,
    IReadOnlyList<int> StarLordOccupies,
    IReadOnlyList<int> StarLordOwns,
    IReadOnlyList<int> Occupies,
    IReadOnlyList<int> Owns);

/// <summary>
/// KP's planetary significators: which houses each planet speaks for, and how
/// strongly.
///
/// KP does not read a planet's own placement as the main thing it signifies.
/// A planet first delivers the results of the star (nakshatra) it sits in —
/// "a planet is the agent of its star lord" — and only then its own. That
/// gives the four levels every KP table prints, strongest first:
///
///   A  houses OCCUPIED by the planet's star lord
///   B  houses OWNED    by the planet's star lord
///   C  houses OCCUPIED by the planet itself
///   D  houses OWNED    by the planet itself
///
/// "Owns" means the houses whose cusp falls in a sign this planet rules — in
/// Placidus that is not one house per planet, since houses are unequal and a
/// sign can hold two cusps or none.
///
/// NOT YET CONFIRMED BY JAY. This is the standard four-level rule as taught in
/// mainstream KP, but schools differ on the details — whether to include a
/// planet conjoined with the star lord, and how Rahu/Ketu signify (they have
/// no signs of their own, so some traditions substitute their dispositor or
/// the planets they are conjoined with). Neither refinement is applied here;
/// Rahu and Ketu simply own nothing. See TASKLIST.md.
/// </summary>
public static class KpSignificatorCalculator
{
    public static IReadOnlyList<KpSignificatorInfo> Compute(
        IReadOnlyList<KpPlanetInfo> planets,
        IReadOnlyList<KpCuspInfo> cusps)
    {
        // Every body in the KP table except the Ascendant, which is a point:
        // it acts as no one's agent and rules nothing, so it takes no row.
        //
        // That includes Uranus, Neptune and Pluto. Three of the four levels
        // are genuinely computable for them — they sit in a nakshatra, so they
        // have a star lord, and they occupy a house. Only "owns" is empty,
        // because they rule no sign in any scheme this app uses. Classical KP
        // leaves them out entirely; they are shown here because the KP table
        // already lists them and a planet present in one view and absent from
        // the next reads as a gap rather than a decision.
        var grahas = planets.Where(p => p.Planet != "Ascendant").ToList();

        var houseOccupiedBy = grahas.ToDictionary(p => p.Planet, p => p.House);

        // Houses owned, read off the cusps rather than assumed one-per-sign:
        // a house is owned by whoever rules the sign its cusp falls in.
        var housesOwnedBy = new Dictionary<string, List<int>>();
        foreach (var cusp in cusps)
        {
            var ruler = KpLordshipCalculator.RulerOfSign[cusp.SignIndex];
            if (!housesOwnedBy.TryGetValue(ruler, out var list))
            {
                housesOwnedBy[ruler] = list = [];
            }
            list.Add(cusp.House);
        }

        static IReadOnlyList<int> Sorted(IEnumerable<int> houses) =>
            houses.Distinct().Order().ToList();

        return grahas.Select(p =>
        {
            var starLord = p.Lordship.StarLord;

            // A star lord is always one of the nine grahas, so it always has a
            // house — but guard anyway rather than throw inside a chart read.
            var starLordHouses = houseOccupiedBy.TryGetValue(starLord, out var h)
                ? new[] { h }
                : [];

            return new KpSignificatorInfo(
                p.Planet,
                StarLordOccupies: Sorted(starLordHouses),
                StarLordOwns: Sorted(housesOwnedBy.GetValueOrDefault(starLord, [])),
                Occupies: Sorted([p.House]),
                Owns: Sorted(housesOwnedBy.GetValueOrDefault(p.Planet, [])));
        }).ToList();
    }
}

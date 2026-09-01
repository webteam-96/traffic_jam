namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// Mangal (Kuja) Dosha — three independent classical checks, each true when
/// Mars falls in houses 1, 2, 4, 7, 8, or 12 counted from that reference
/// point. <see cref="FromLagna"/>/<see cref="HouseFromLagna"/> are null when
/// the birth time is unknown (no Ascendant, same convention used everywhere
/// else in this engine) — the Moon- and Venus-based checks don't need a
/// birth time and are always populated.
///
/// <see cref="MarsInOwnOrExaltedSign"/> flags the single most universally
/// agreed-upon partial-cancellation condition (Mars in Aries/Scorpio — its
/// own signs — or Capricorn — its exaltation) so a "Manglik: yes" isn't
/// shown without this important context. Fuller cancellation rules
/// (Jupiter's aspect, both partners being Manglik, etc.) are more debated
/// across texts and deliberately left out rather than asserted as settled.
/// </summary>
public record MangalDoshaInfo(
    bool? FromLagna, int? HouseFromLagna,
    bool FromMoon, int HouseFromMoon,
    bool FromVenus, int HouseFromVenus,
    bool MarsInOwnOrExaltedSign);

/// <summary>
/// Kaal Sarp Dosha — present when all seven classical planets (Sun through
/// Saturn) fall within the same 180° half of the zodiac split by the
/// Rahu-Ketu axis, i.e. none of them "cross" to Ketu's side. Purely
/// geometric — no interpretation involved. <see cref="SubType"/> is one of
/// the 12 classically-named variants, keyed to which house Rahu occupies
/// from the Lagna; null when the birth time is unknown or the dosha isn't
/// present.
/// </summary>
public record KaalSarpDoshaInfo(bool IsPresent, string? SubType, int? RahuHouseFromLagna);

public record NatalDoshaResult(MangalDoshaInfo Mangal, KaalSarpDoshaInfo KaalSarp);

/// <summary>
/// Sade Sati — active when transiting Saturn sits in the sign before, the
/// same sign as, or the sign after the natal Moon (houses 12, 1, 2 counted
/// from the Moon). Phase boundaries and the full-cycle end are found by
/// scanning forward/backward for the day Saturn's house-from-Moon next
/// changes — the same technique <see cref="TransitEndpoints"/>'s
/// upcoming-ingress scan uses, just applied to one specific planet/window.
/// </summary>
public record SadeSatiInfo(
    bool IsActive, string? Phase,
    DateOnly? PhaseStartedOn, DateOnly? PhaseEndsOn, DateOnly? FullCycleEndsOn);

public interface IDoshaService
{
    NatalDoshaResult ComputeNatalDoshas(IReadOnlyList<PlanetPosition> d1, int? ascendantSignIndex);
    SadeSatiInfo ComputeSadeSati(int natalMoonSignIndex, DateOnly today);
}

public class DoshaService(ITransitService transitService) : IDoshaService
{
    private static readonly int[] MangalHouses = [1, 2, 4, 7, 8, 12];

    // Rahu in house 1 -> Anant, house 2 -> Kulik, ... house 12 -> Shesh —
    // consistently listed in this order across classical sources.
    private static readonly string[] KaalSarpSubTypes =
    [
        "Anant", "Kulik", "Vasuki", "Shankhpal", "Padma", "Mahapadma",
        "Takshak", "Karkotak", "Shankhchood", "Ghatak", "Vishdhar", "Shesh",
    ];

    public NatalDoshaResult ComputeNatalDoshas(IReadOnlyList<PlanetPosition> d1, int? ascendantSignIndex)
    {
        var mars = d1.Single(p => p.Planet == "Mars");
        var moon = d1.Single(p => p.Planet == "Moon");
        var venus = d1.Single(p => p.Planet == "Venus");

        var houseFromMoon = VedicMath.HouseFromSign(mars.SignIndex, moon.SignIndex);
        var houseFromVenus = VedicMath.HouseFromSign(mars.SignIndex, venus.SignIndex);
        int? houseFromLagna = ascendantSignIndex is null
            ? null
            : VedicMath.HouseFromSign(mars.SignIndex, ascendantSignIndex.Value);

        // Aries(0)/Scorpio(7) = Mars' own signs; Capricorn(9) = its exaltation.
        var marsOwnOrExalted = mars.SignIndex is 0 or 7 or 9;

        var mangal = new MangalDoshaInfo(
            FromLagna: houseFromLagna is null ? null : MangalHouses.Contains(houseFromLagna.Value),
            HouseFromLagna: houseFromLagna,
            FromMoon: MangalHouses.Contains(houseFromMoon), HouseFromMoon: houseFromMoon,
            FromVenus: MangalHouses.Contains(houseFromVenus), HouseFromVenus: houseFromVenus,
            MarsInOwnOrExaltedSign: marsOwnOrExalted);

        return new NatalDoshaResult(mangal, ComputeKaalSarp(d1, ascendantSignIndex));
    }

    private static KaalSarpDoshaInfo ComputeKaalSarp(IReadOnlyList<PlanetPosition> d1, int? ascendantSignIndex)
    {
        var rahu = d1.Single(p => p.Planet == "Rahu");
        var rahuLongitude = rahu.SignIndex * 30.0 + rahu.DegreeInSign;

        string[] sevenPlanets = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
        var onForwardSide = sevenPlanets.Select(name =>
        {
            var p = d1.Single(x => x.Planet == name);
            var longitude = p.SignIndex * 30.0 + p.DegreeInSign;
            return VedicMath.Normalize(longitude - rahuLongitude) < 180.0;
        }).ToList();

        var isPresent = onForwardSide.All(x => x) || onForwardSide.All(x => !x);

        string? subType = null;
        int? rahuHouse = null;
        if (isPresent && ascendantSignIndex is not null)
        {
            rahuHouse = VedicMath.HouseFromSign(rahu.SignIndex, ascendantSignIndex.Value);
            subType = KaalSarpSubTypes[rahuHouse.Value - 1];
        }

        return new KaalSarpDoshaInfo(isPresent, subType, rahuHouse);
    }

    public SadeSatiInfo ComputeSadeSati(int natalMoonSignIndex, DateOnly today)
    {
        int HouseFromMoonOn(DateOnly date) => transitService
            .Compute(date, natalLagnaSignIndex: null, natalMoonSignIndex)
            .Planets.Single(p => p.Planet == "Saturn").HouseFromMoon;

        var todayHouse = HouseFromMoonOn(today);
        if (todayHouse is not (12 or 1 or 2))
        {
            return new SadeSatiInfo(false, null, null, null, null);
        }

        var phase = todayHouse switch { 12 => "Rising", 1 => "Peak", 2 => "Setting", _ => null };
        var phaseStart = ScanBackwardForStart(today, todayHouse, HouseFromMoonOn);
        var phaseEnd = ScanForwardWhileInHouse(today, todayHouse, HouseFromMoonOn);
        var cycleEnd = ScanForwardUntilOutsideSadeSati(phaseEnd, HouseFromMoonOn);

        return new SadeSatiInfo(true, phase, phaseStart, phaseEnd, cycleEnd);
    }

    // Saturn's dwell in one sign is under ~3 years even accounting for
    // retrograde wobble near a sign boundary — 1,200 days is a safe margin
    // for finding a single phase's start or end.
    private const int SinglePhaseScanDays = 1200;

    // The full ~7.5-year Sade Sati cycle is three such dwells; scanning from
    // the current phase's end (not from today) keeps this bounded to what's
    // actually left of the cycle.
    private const int CycleScanDays = 3 * SinglePhaseScanDays;

    private static DateOnly ScanBackwardForStart(DateOnly today, int currentHouse, Func<DateOnly, int> houseFn)
    {
        var date = today;
        for (var i = 0; i < SinglePhaseScanDays; i++)
        {
            var prev = date.AddDays(-1);
            if (houseFn(prev) != currentHouse) return date;
            date = prev;
        }
        return date;
    }

    private static DateOnly ScanForwardWhileInHouse(DateOnly today, int currentHouse, Func<DateOnly, int> houseFn)
    {
        var date = today;
        for (var i = 0; i < SinglePhaseScanDays; i++)
        {
            var next = date.AddDays(1);
            if (houseFn(next) != currentHouse) return date;
            date = next;
        }
        return date;
    }

    private static DateOnly ScanForwardUntilOutsideSadeSati(DateOnly from, Func<DateOnly, int> houseFn)
    {
        var date = from;
        for (var i = 0; i < CycleScanDays; i++)
        {
            var next = date.AddDays(1);
            if (houseFn(next) is not (12 or 1 or 2)) return date;
            date = next;
        }
        return date;
    }
}

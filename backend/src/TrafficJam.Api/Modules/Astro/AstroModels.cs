namespace TrafficJam.Api.Modules.Astro;

/// <summary>One planet's placement in a chart (D1 or a divisional chart).</summary>
public record PlanetPosition(
    string Planet,
    int SignIndex,
    string Sign,
    double DegreeInSign,
    int? House,
    bool Retrograde);

public record NakshatraInfo(string Name, int Index, int Pada);

/// <summary>
/// Full output of one birth-chart computation — everything BACKEND_REQUIREMENTS.md
/// defines as "the birth chart" (Lagna, 9 planets with house placement,
/// Navamsha, Nakshatra) plus the Kundli-expansion divisional charts D10 and
/// D60. KP sub-lords/Cusp chart are a deliberately separate, not-yet-built
/// follow-up — see AstroEngineService's class comment. D60 is null when
/// <c>timeKnown</c> is false — see AstroEngineService.ComputeBirthChart's
/// doc comment for why it, unlike D9/D10, needs a genuinely exact birth time.
/// The three Ascendant fields are null for the same "no birth time" reason —
/// there is no honest Lagna without a real clock time, so this reports
/// "unknown" instead of silently defaulting to Aries (0°), which is what
/// this record used to do before every caller had to be checked and fixed.
/// </summary>
public record BirthChartResult(
    double AyanamsaDegrees,
    double? AscendantTropicalLongitude,
    double? AscendantSiderealLongitude,
    int? AscendantSignIndex,
    IReadOnlyList<PlanetPosition> D1,
    IReadOnlyList<PlanetPosition> D9,
    IReadOnlyList<PlanetPosition> D10,
    IReadOnlyList<PlanetPosition>? D60,
    IReadOnlyList<PlanetPosition> MoonChart,
    NakshatraInfo MoonNakshatra);

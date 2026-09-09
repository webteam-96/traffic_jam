namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// The version of the astrology engine's OUTPUT — not of the code, of what a
/// stored chart contains.
///
/// Bump <see cref="Current"/> whenever a change means an existing stored chart
/// is no longer what the engine would produce today. Charts below it are
/// recomputed the next time they are read.
///
/// History:
///   0  Everything before versioning existed. Nine grahas, KP on the Lahiri
///      ayanamsa, no Ascendant row in the KP table, no retrograde in KP.
///   1  KP computed on the Krishnamurti ayanamsa with its own Ascendant row
///      and retrograde flags; Uranus, Neptune and Pluto in every chart.
/// </summary>
public static class AstroEngineVersion
{
    public const int Current = 1;
}

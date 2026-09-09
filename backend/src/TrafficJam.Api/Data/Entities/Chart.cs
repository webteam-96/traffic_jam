namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// The permanent, one-time-computed birth chart (Astro Engine output).
/// Regenerated only when birth data changes. Divisional charts beyond D1/D9
/// (D10, D60, KP, Cusp — added for the Kundli expansion) live in their own
/// JSON columns rather than new tables, since they're all read-only,
/// generated-together artifacts of the same computation.
/// </summary>
public class Chart
{
    public Guid UserId { get; set; }
    public required string D1Json { get; set; }
    public required string D9Json { get; set; }
    public required string D10Json { get; set; }
    public required string D60Json { get; set; }
    public required string MoonJson { get; set; }
    public required string KpJson { get; set; }
    public required string CuspJson { get; set; }
    public required string Nakshatra { get; set; }
    public required string Ayanamsa { get; set; }

    /// <summary>
    /// Which version of the astrology engine produced this row.
    ///
    /// A chart is computed once and stored, so every improvement to the engine
    /// used to be invisible to anyone who already had one — their chart stayed
    /// frozen at whatever the code did the day they saved their birth details.
    /// That silently cost existing users the KP ayanamsa correction, the
    /// Ascendant row in the KP table, retrograde flags, and Uranus/Neptune/
    /// Pluto.
    ///
    /// Reading a chart older than <see cref="AstroEngineVersion.Current"/>
    /// recomputes it from the same birth data and stores the result. Bump that
    /// constant whenever a change alters what the engine produces.
    /// </summary>
    public int EngineVersion { get; set; }

    public DateTime ComputedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}

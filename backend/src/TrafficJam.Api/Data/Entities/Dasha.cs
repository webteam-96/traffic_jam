namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// The user's current Vimshottari Dasha state — refreshed monthly by the
/// scheduled job. Full Maha/Antar/Pratyantar period lists are stored as JSON
/// since they're an ordered tree the app renders directly, not something
/// queried by individual field.
/// </summary>
public class Dasha
{
    public Guid UserId { get; set; }
    public required string MahaJson { get; set; }
    public required string AntarJson { get; set; }
    public required string PratyantarJson { get; set; }

    /// <summary>First day of the month this snapshot was computed for.</summary>
    public required DateOnly ValidMonth { get; set; }

    public User User { get; set; } = null!;
}

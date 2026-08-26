namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// Content-team-authored remedy catalog (admin panel CMS territory). Not
/// user-specific — the Astro Engine selects and personalises from this set
/// based on each user's weak planets and current triggers.
/// </summary>
public class RemedyContent
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Type { get; set; }
    public required string Title { get; set; }
    public required string Detail { get; set; }

    /// <summary>Machine-readable rule the batch job evaluates against a user's chart (e.g. weak-planet-in-transit, hard-Dasha).</summary>
    public required string TriggerRule { get; set; }

    public string? AudioUrl { get; set; }
}

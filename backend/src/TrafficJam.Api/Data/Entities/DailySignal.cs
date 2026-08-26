namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// One row per user per day — the nightly batch's precomputed Traffic Signal
/// score. Composite key (UserId, Date) since a user has at most one per day.
/// </summary>
public class DailySignal
{
    public Guid UserId { get; set; }
    public required DateOnly Date { get; set; }

    /// <summary>0-100 composite score.</summary>
    public required int Score { get; set; }

    /// <summary>Green (70-100) / Yellow (40-69) / Red (0-39).</summary>
    public required string Band { get; set; }

    /// <summary>The 30/25/25/20 factor breakdown (Moon transit / Panchang / Dasha / major transits) with plain-language drivers.</summary>
    public required string BreakdownJson { get; set; }

    public DateTime ComputedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}

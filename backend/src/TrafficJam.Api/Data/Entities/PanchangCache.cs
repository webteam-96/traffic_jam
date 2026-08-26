namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// One computation per city per day, shared across every user in that city
/// — not user-specific. Composite key (City, Date).
/// </summary>
public class PanchangCache
{
    public required string City { get; set; }
    public required DateOnly Date { get; set; }
    public required string Tithi { get; set; }
    public required string Nakshatra { get; set; }
    public required string Yoga { get; set; }
    public required string Karana { get; set; }
    public required TimeOnly RahuKaalStart { get; set; }
    public required TimeOnly RahuKaalEnd { get; set; }
    public required TimeOnly AbhijitStart { get; set; }
    public required TimeOnly AbhijitEnd { get; set; }
    public required TimeOnly Sunrise { get; set; }
    public required TimeOnly Sunset { get; set; }
    public DateTime ComputedAt { get; set; } = DateTime.UtcNow;
}

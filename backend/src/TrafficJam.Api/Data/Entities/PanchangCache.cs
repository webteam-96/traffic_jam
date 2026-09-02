namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// One computation per city per day, shared across every user in that city
/// — not user-specific. Composite key (City, Date).
/// </summary>
public class PanchangCache
{
    public required string City { get; set; }
    public required DateOnly Date { get; set; }
    public required string Paksha { get; set; }
    public required string Tithi { get; set; }
    public required DateTime TithiEndsAt { get; set; }
    public required string Nakshatra { get; set; }
    public required DateTime NakshatraEndsAt { get; set; }
    public required string Yoga { get; set; }
    public required DateTime YogaEndsAt { get; set; }
    public required string Karana { get; set; }
    public required DateTime KaranaEndsAt { get; set; }
    // Full UTC instants, not TimeOnly — a wall-clock time alone can't be
    // reattached to the right UTC calendar date later (an evening event in a
    // positive-offset timezone, or a morning one in a negative-offset
    // timezone, can land on a different UTC date than `Date` itself).
    public required DateTime RahuKaalStart { get; set; }
    public required DateTime RahuKaalEnd { get; set; }
    public required DateTime YamagandaKaalStart { get; set; }
    public required DateTime YamagandaKaalEnd { get; set; }
    public required DateTime GulikaKaalStart { get; set; }
    public required DateTime GulikaKaalEnd { get; set; }
    public required DateTime AbhijitStart { get; set; }
    public required DateTime AbhijitEnd { get; set; }
    // Null when Abhijit is entirely swallowed by Rahu Kaal/Yamaganda/Gulika
    // that day — see PanchangService.TrimAgainstInauspicious.
    public DateTime? AbhijitCleanStart { get; set; }
    public DateTime? AbhijitCleanEnd { get; set; }
    public required DateTime Sunrise { get; set; }
    public required DateTime Sunset { get; set; }
    public DateTime? Moonrise { get; set; }
    public DateTime? Moonset { get; set; }
    public DateTime ComputedAt { get; set; } = DateTime.UtcNow;
}

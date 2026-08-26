namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// One row per user — the three mandatory ephemeris inputs (dob/tob/lat/lng)
/// plus place and timezone. Dob, Tob, Place, Lat and Lng are AES-256
/// encrypted at rest via EF Core value converters configured in
/// <see cref="AppDbContext"/> — application code reads/writes plain values,
/// the database only ever sees ciphertext.
/// </summary>
public class BirthData
{
    public Guid UserId { get; set; }
    public required DateOnly Dob { get; set; }
    public TimeOnly? Tob { get; set; }
    public bool UnknownTime { get; set; }
    public required string Place { get; set; }
    public required double Lat { get; set; }
    public required double Lng { get; set; }

    /// <summary>IANA timezone id (e.g. "Asia/Kolkata") — not sensitive, kept plain for query/scheduling use.</summary>
    public required string Timezone { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}

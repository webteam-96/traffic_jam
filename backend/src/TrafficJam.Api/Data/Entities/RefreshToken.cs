namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// A single refresh token issued alongside a short-lived app JWT. Stored as
/// a hash, never the raw token — same principle as the phone-hash on User.
/// Rotation: redeeming a refresh token issues a new one and revokes this row.
/// </summary>
public class RefreshToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string TokenHash { get; set; }
    public required DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAt { get; set; }

    public User User { get; set; } = null!;
}

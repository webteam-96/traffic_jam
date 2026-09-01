namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// Internal staff/astrologer login for the admin panel — deliberately a
/// separate table from User (consumer accounts authenticate by phone+OTP;
/// this is email+password, and the two actor types should never share a
/// login path or a JWT that could be mistaken for the other's).
/// </summary>
public class AdminUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Email { get; set; }
    public required string PasswordHash { get; set; }
    public required string Name { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

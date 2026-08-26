namespace TrafficJam.Api.Data.Entities;

public class Device
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string FcmToken { get; set; }
    public required string Platform { get; set; }
    public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}

namespace TrafficJam.Api.Data.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>SHA-256 hash of the E.164 phone number — never stored in plain text.</summary>
    public required string PhoneHash { get; set; }

    public required string FirebaseUid { get; set; }
    public string? Name { get; set; }
    public string? AvatarUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public BirthData? BirthData { get; set; }
    public Chart? Chart { get; set; }
    public Dasha? Dasha { get; set; }
    public Subscription? Subscription { get; set; }
    public NotificationPrefs? NotificationPrefs { get; set; }
    public OnboardingDraft? OnboardingDraft { get; set; }
    public ICollection<Device> Devices { get; set; } = [];
    public ICollection<Question> Questions { get; set; } = [];
    public ICollection<DailySignal> DailySignals { get; set; } = [];
    public ICollection<RefreshToken> RefreshTokens { get; set; } = [];
    public ICollection<Notification> Notifications { get; set; } = [];
    public ICollection<Appointment> Appointments { get; set; } = [];
}

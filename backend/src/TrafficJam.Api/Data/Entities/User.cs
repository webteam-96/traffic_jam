namespace TrafficJam.Api.Data.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>
    /// SHA-256 hash of the E.164 phone number. This is a *lookup key*, not the
    /// stored number (see <see cref="Phone"/>): sign-in hashes the number the
    /// caller presents and matches it here to recognise a returning user whose
    /// auth UID changed (reinstall, re-verification, SIM swap), and its unique
    /// index is what enforces one account per number. It stays deterministic
    /// precisely so it can be queried — <see cref="Phone"/>'s AES-GCM
    /// ciphertext differs on every write and can never be matched in a WHERE.
    /// </summary>
    public required string PhoneHash { get; set; }

    /// <summary>
    /// The readable E.164 phone number, AES-256 encrypted at rest via the value
    /// converter in <see cref="Data.AppDbContext"/> — the database only ever
    /// sees ciphertext, application code reads a plain string. Null for any
    /// account created before this column existed: those numbers were only ever
    /// hashed, a hash can't be reversed, and there is nothing to backfill from
    /// — it fills in by itself the next time that person signs in.
    /// </summary>
    public string? Phone { get; set; }

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

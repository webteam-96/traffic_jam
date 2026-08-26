namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// Progressive save of name/DOB/time/place while a user is mid-onboarding,
/// so a dropped session can resume — API_REQUIREMENTS.md §1.5. Deleted once
/// /onboarding/complete succeeds.
/// </summary>
public class OnboardingDraft
{
    public Guid UserId { get; set; }
    public string? Name { get; set; }
    public DateOnly? Dob { get; set; }
    public TimeOnly? Tob { get; set; }
    public bool UnknownTime { get; set; }
    public string? Place { get; set; }
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public string? Timezone { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}

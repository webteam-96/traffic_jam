namespace TrafficJam.Api.Data.Entities;

public enum AppointmentStatus
{
    Pending,
    Confirmed,
    Completed,
    Cancelled,
}

/// <summary>
/// A consultation appointment request from "Book Appointment" — Business
/// Flow §9. No scheduling/admin panel exists yet (Phase 2), so every
/// request lands here as Pending; a human on the team follows up outside
/// the app for now, using the Reference for lookup.
/// </summary>
public class Appointment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string Area { get; set; }
    public required string Email { get; set; }
    public string? Message { get; set; }
    public required DateOnly PreferredDate { get; set; }
    public required TimeOnly PreferredTime { get; set; }
    public AppointmentStatus Status { get; set; } = AppointmentStatus.Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}

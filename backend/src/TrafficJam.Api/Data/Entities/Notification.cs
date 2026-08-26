namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// One inbox entry — API_REQUIREMENTS.md §6.1. Covers both system-generated
/// alerts (morning briefing, Rahu Kaal, transits) and team announcements,
/// matching the frontend's System/Team filter (notifications_screen.dart).
/// </summary>
public enum NotificationSource
{
    System,
    Team,
}

public class Notification
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string Type { get; set; }
    public required string Title { get; set; }
    public required string Body { get; set; }
    public NotificationSource Source { get; set; } = NotificationSource.System;
    public bool Read { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}

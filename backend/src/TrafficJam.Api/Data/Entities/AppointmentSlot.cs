namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// A window of availability the astrologer has published.
///
/// Stored in UTC. Slots are offered to users in their own timezone and booked
/// against this instant, so two people in different places see the same slot
/// at the right local hour and cannot both take it.
///
/// Deliberately carries no "IsBooked" flag. Whether a slot is taken is derived
/// from whether an Appointment points at it — one source of truth, so a
/// cancelled booking can never leave a flag saying "booked" behind it.
/// </summary>
public class AppointmentSlot
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Start of the window, UTC.</summary>
    public DateTime StartsAt { get; set; }

    public int DurationMinutes { get; set; } = 30;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>The booking that took this slot, if any. Null means free.</summary>
    public Appointment? Appointment { get; set; }
}

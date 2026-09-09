namespace TrafficJam.Api.Data.Entities;

public enum AppointmentStatus
{
    Pending,
    Confirmed,
    Completed,
    Cancelled,
}

/// <summary>
/// A consultation booking from "Book Appointment" — Business Flow §9.
///
/// Two ways one is made:
///
///   Booking a published slot. The astrologer already said they are free
///   then, so there is nothing left to agree — it lands Confirmed and takes
///   the slot out of circulation for everyone else.
///
///   Asking for a time of the user's own choosing, when no published slot
///   suits. That is a request, not a booking: it lands Pending and only
///   becomes real if the astrologer confirms it.
/// </summary>
public class Appointment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string Area { get; set; }
    public required string Email { get; set; }
    public string? Message { get; set; }
    /// <summary>
    /// The published slot this booking took, or null for a manual request.
    /// Uniquely indexed, so the database itself refuses a double booking —
    /// two people tapping the same slot at the same moment is a race that
    /// application checks alone cannot win.
    ///
    /// Cleared when a booking is cancelled, which is what returns the slot to
    /// the pool; ScheduledAt keeps the record of when it had been.
    /// </summary>
    public Guid? SlotId { get; set; }

    /// <summary>
    /// The agreed instant, UTC — set from the slot on booking, or by the
    /// astrologer when confirming a manual request. Null while a request is
    /// still just a request.
    /// </summary>
    public DateTime? ScheduledAt { get; set; }

    /// <summary>What the user asked for, in their own words of date and time.
    /// Kept for manual requests; for a slot booking it mirrors the slot.</summary>
    public required DateOnly PreferredDate { get; set; }
    public required TimeOnly PreferredTime { get; set; }

    /// <summary>
    /// IANA zone the user was reading times in when they booked, e.g.
    /// "Asia/Kolkata". Without it a request for "3 PM" is ambiguous, and the
    /// astrologer has no way to know which 3 PM was meant.
    /// </summary>
    public string? Timezone { get; set; }
    public AppointmentStatus Status { get; set; } = AppointmentStatus.Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
    public AppointmentSlot? Slot { get; set; }
}

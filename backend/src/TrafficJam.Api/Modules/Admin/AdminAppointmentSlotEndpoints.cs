using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Admin;

/// <summary>Times to publish, UTC. Several at once because availability is
/// usually set a day or a week at a time, not one hour at a time.</summary>
public record CreateSlotsRequest(IReadOnlyList<DateTime> StartsAt, int DurationMinutes = 30);

public record AdminSlotResponse(
    Guid Id, DateTime StartsAt, int DurationMinutes, bool IsBooked, string? BookedBy);

/// <summary>
/// The astrologer's published availability. Users only ever see slots created
/// here, and only the ones nobody has taken.
/// </summary>
public static class AdminAppointmentSlotEndpoints
{
    public static void MapAdminAppointmentSlotEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/admin/appointment-slots").RequireAuthorization("AdminOnly");

        // Everything from today onward, booked or not — the admin needs to see
        // what is taken as much as what is free.
        group.MapGet("", async (AppDbContext db, CancellationToken ct) =>
        {
            var from = DateTime.UtcNow.Date;
            var slots = await db.AppointmentSlots
                .Where(sl => sl.StartsAt >= from)
                .OrderBy(sl => sl.StartsAt)
                .Select(sl => new AdminSlotResponse(
                    sl.Id,
                    sl.StartsAt,
                    sl.DurationMinutes,
                    sl.Appointment != null,
                    sl.Appointment != null ? sl.Appointment.Email : null))
                .ToListAsync(ct);

            return Results.Ok(slots);
        });

        group.MapPost("", async (CreateSlotsRequest request, AppDbContext db, CancellationToken ct) =>
        {
            if (request.StartsAt.Count == 0)
            {
                return Results.BadRequest(new { error = new { code = "NO_TIMES", message = "Pick at least one time." } });
            }

            if (request.DurationMinutes is < 5 or > 240)
            {
                return Results.BadRequest(new { error = new { code = "BAD_DURATION", message = "Duration must be 5 to 240 minutes." } });
            }

            var now = DateTime.UtcNow;
            var wanted = request.StartsAt
                .Select(t => DateTime.SpecifyKind(t, DateTimeKind.Utc))
                .Where(t => t > now)
                .Distinct()
                .ToList();

            if (wanted.Count == 0)
            {
                return Results.BadRequest(new
                {
                    error = new { code = "TIMES_IN_PAST", message = "Those times have already passed." },
                });
            }

            // Publishing the same hour twice would offer users two slots for
            // one appointment, so existing times are skipped rather than
            // duplicated — re-publishing a day is then safe to do twice.
            var existing = await db.AppointmentSlots
                .Where(sl => wanted.Contains(sl.StartsAt))
                .Select(sl => sl.StartsAt)
                .ToListAsync(ct);

            var created = wanted
                .Where(t => !existing.Contains(t))
                .Select(t => new AppointmentSlot { StartsAt = t, DurationMinutes = request.DurationMinutes })
                .ToList();

            db.AppointmentSlots.AddRange(created);
            await db.SaveChangesAsync(ct);

            return Results.Ok(new { created = created.Count, skipped = wanted.Count - created.Count });
        });

        group.MapDelete("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var slot = await db.AppointmentSlots
                .Include(sl => sl.Appointment)
                .SingleOrDefaultAsync(sl => sl.Id == id, ct);

            if (slot is null) return Results.NotFound();

            if (slot.Appointment is not null)
            {
                // Deleting a booked slot would strand a real appointment with
                // nothing behind it. Cancel the booking first — that frees the
                // slot, and the user is told rather than silently dropped.
                return Results.Conflict(new
                {
                    error = new
                    {
                        code = "SLOT_BOOKED",
                        message = "Someone has booked this slot. Cancel their appointment first.",
                    },
                });
            }

            db.AppointmentSlots.Remove(slot);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }
}

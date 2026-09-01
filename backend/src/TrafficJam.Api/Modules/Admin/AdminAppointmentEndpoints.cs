using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Admin;

public record AdminAppointmentSummary(
    Guid Id, string? UserName, string Area, string Email, string? Message,
    DateOnly PreferredDate, TimeOnly PreferredTime, string Status, DateTime CreatedAt);

public record AdminUpdateAppointmentStatusRequest(string Status);

public static class AdminAppointmentEndpoints
{
    public static void MapAdminAppointmentEndpoints(this WebApplication app)
    {
        app.MapGet("/admin/appointments", async (string? status, AppDbContext db, CancellationToken ct, int page = 1, int pageSize = 25) =>
        {
            page = page <= 0 ? 1 : page;
            pageSize = pageSize is <= 0 or > 100 ? 25 : pageSize;

            var query = db.Appointments.Include(a => a.User).AsQueryable();
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<AppointmentStatus>(status, true, out var parsed))
            {
                query = query.Where(a => a.Status == parsed);
            }

            var totalCount = await query.CountAsync(ct);
            var appointments = await query
                .OrderBy(a => a.Status == AppointmentStatus.Pending ? 0 : 1)
                .ThenBy(a => a.PreferredDate).ThenBy(a => a.PreferredTime)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(a => new AdminAppointmentSummary(
                    a.Id, a.User.Name, a.Area, a.Email, a.Message,
                    a.PreferredDate, a.PreferredTime, a.Status.ToString(), a.CreatedAt))
                .ToListAsync(ct);

            return Results.Ok(new { appointments, totalCount });
        }).RequireAuthorization("AdminOnly");

        app.MapPatch("/admin/appointments/{id:guid}/status", async (
            Guid id, AdminUpdateAppointmentStatusRequest request, AppDbContext db, CancellationToken ct) =>
        {
            if (!Enum.TryParse<AppointmentStatus>(request.Status, true, out var newStatus))
            {
                return Results.Json(new { error = new { code = "INVALID_STATUS", message = $"Unknown status '{request.Status}'." } },
                    statusCode: StatusCodes.Status400BadRequest);
            }

            var appointment = await db.Appointments.SingleOrDefaultAsync(a => a.Id == id, ct);
            if (appointment is null) return Results.NotFound();

            appointment.Status = newStatus;
            await db.SaveChangesAsync(ct);
            return Results.Ok();
        }).RequireAuthorization("AdminOnly");
    }
}

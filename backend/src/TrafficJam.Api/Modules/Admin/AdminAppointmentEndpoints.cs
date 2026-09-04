using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Admin;

public record AdminAppointmentSummary(
    Guid Id, Guid UserId, string? UserName, string Area, string Email, string? Message,
    DateOnly PreferredDate, TimeOnly PreferredTime, string Status, DateTime CreatedAt,
    string? BirthPlace, DateOnly? Dob, TimeOnly? Tob, bool? UnknownTime);

public record AdminUpdateAppointmentStatusRequest(string Status);

public static class AdminAppointmentEndpoints
{
    public static void MapAdminAppointmentEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/admin/appointments", async (string? status, AppDbContext db, CancellationToken ct, int page = 1, int pageSize = 25) =>
        {
            page = page <= 0 ? 1 : page;
            pageSize = pageSize is <= 0 or > 100 ? 25 : pageSize;

            // Materialized (not a .Select() projection) before mapping to
            // AdminAppointmentSummary — BirthData's Dob/Place/Tob are AES
            // encrypted at rest via EF value converters (see BirthData.cs),
            // and letting EF hydrate real entities first, the same pattern
            // AdminUserEndpoints' user-detail lookup already uses, is the
            // safe way to get decrypted values rather than projecting the
            // encrypted columns directly in a server-translated query.
            var query = db.Appointments.Include(a => a.User).ThenInclude(u => u.BirthData).AsQueryable();
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<AppointmentStatus>(status, true, out var parsed))
            {
                query = query.Where(a => a.Status == parsed);
            }

            var totalCount = await query.CountAsync(ct);
            var appointments = await query
                .OrderBy(a => a.Status == AppointmentStatus.Pending ? 0 : 1)
                .ThenBy(a => a.PreferredDate).ThenBy(a => a.PreferredTime)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .ToListAsync(ct);

            var summaries = appointments.Select(a => new AdminAppointmentSummary(
                a.Id, a.UserId, a.User.Name, a.Area, a.Email, a.Message,
                a.PreferredDate, a.PreferredTime, a.Status.ToString(), a.CreatedAt,
                a.User.BirthData?.Place, a.User.BirthData?.Dob, a.User.BirthData?.Tob, a.User.BirthData?.UnknownTime));

            return Results.Ok(new { appointments = summaries, totalCount });
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

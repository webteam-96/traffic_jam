using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Notifications;

public record NotificationResponse(Guid Id, string Type, string Title, string Body, string Source, DateTime At, bool Read);

public static class NotificationEndpoints
{
    public static void MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/notifications").RequireAuthorization();

        group.MapGet("/", async (
            bool? unread, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            INotificationGenerator generator, CancellationToken ct) =>
        {
            var userId = principal.UserId();

            // Fill the inbox before reading it. Nothing else writes
            // notifications — there is no scheduler yet — so without this the
            // table stays empty forever, which is exactly how it shipped.
            await generator.EnsureAsync(userId, ct);

            var query = db.Notifications.Where(n => n.UserId == userId);
            if (unread == true) query = query.Where(n => !n.Read);

            var results = await query
                .OrderByDescending(n => n.CreatedAt)
                .Select(n => new NotificationResponse(
                    n.Id, n.Type, n.Title, n.Body, n.Source.ToString().ToLower(), n.CreatedAt, n.Read))
                .ToListAsync(ct);

            return Results.Ok(results);
        });

        group.MapPost("/{id:guid}/read", async (
            Guid id, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var notification = await db.Notifications.SingleOrDefaultAsync(n => n.Id == id && n.UserId == userId, ct);
            if (notification is null) return Results.NotFound();

            notification.Read = true;
            await db.SaveChangesAsync(ct);
            return Results.Ok();
        });

        // Convenience beyond the documented contract — the "mark all read" action in
        // the app would otherwise mean one request per notification.
        group.MapPost("/read-all", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            await db.Notifications
                .Where(n => n.UserId == userId && !n.Read)
                .ExecuteUpdateAsync(setters => setters.SetProperty(n => n.Read, true), ct);

            return Results.Ok();
        });
    }
}

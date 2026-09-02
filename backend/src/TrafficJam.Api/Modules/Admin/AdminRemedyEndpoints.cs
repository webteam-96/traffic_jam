using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Admin;

public record AdminRemedyRequest(string Type, string Title, string Detail, string TriggerRule, string? AudioUrl);

/// <summary>
/// CRUD over RemedyContent — the "content-team-authored... admin panel CMS
/// territory" catalog RemedyEndpoints.GetRemedies personalises from (see
/// that entity's own doc comment). Before this, the only way to change a
/// remedy was a new EF migration; this is what makes it actually
/// admin-editable.
/// </summary>
public static class AdminRemedyEndpoints
{
    public static void MapAdminRemedyEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/admin/remedies").RequireAuthorization("AdminOnly");

        group.MapGet("", async (AppDbContext db, CancellationToken ct) =>
            Results.Ok(await db.RemedyContent.OrderBy(r => r.TriggerRule).ThenBy(r => r.Title).ToListAsync(ct)));

        group.MapPost("", async (AdminRemedyRequest request, AppDbContext db, CancellationToken ct) =>
        {
            var remedy = new RemedyContent
            {
                Type = request.Type, Title = request.Title, Detail = request.Detail,
                TriggerRule = request.TriggerRule, AudioUrl = request.AudioUrl,
            };
            db.RemedyContent.Add(remedy);
            await db.SaveChangesAsync(ct);
            return Results.Ok(remedy);
        });

        group.MapPut("/{id:guid}", async (Guid id, AdminRemedyRequest request, AppDbContext db, CancellationToken ct) =>
        {
            var remedy = await db.RemedyContent.SingleOrDefaultAsync(r => r.Id == id, ct);
            if (remedy is null) return Results.NotFound();

            remedy.Type = request.Type;
            remedy.Title = request.Title;
            remedy.Detail = request.Detail;
            remedy.TriggerRule = request.TriggerRule;
            remedy.AudioUrl = request.AudioUrl;
            await db.SaveChangesAsync(ct);
            return Results.Ok(remedy);
        });

        group.MapDelete("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var remedy = await db.RemedyContent.SingleOrDefaultAsync(r => r.Id == id, ct);
            if (remedy is null) return Results.NotFound();

            db.RemedyContent.Remove(remedy);
            await db.SaveChangesAsync(ct);
            return Results.Ok();
        });
    }
}

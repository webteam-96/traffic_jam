using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Remedies;

public record RemedyResponse(Guid Id, string Type, string Title, string Detail, string TriggerRule, string? AudioUrl);

/// <summary>
/// `GET /remedies` — personalises RemedyContent (see its doc comment) by the
/// user's current Dasha: general-purpose remedies plus whatever matches
/// their current Mahadasha and Antardasha lord. This is the "select from
/// the seeded catalog based on chart triggers" half of RemedyContent's
/// design; the "batch job re-evaluates as transits change" half is a
/// scheduling concern, not a correctness one, same tradeoff as the Panchang/
/// signal pre-warming cron job noted in backend/README.md.
/// </summary>
public static class RemedyEndpoints
{
    public static void MapRemedyEndpoints(this WebApplication app)
    {
        app.MapGet("/remedies", async (
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var dasha = await db.Dashas.SingleOrDefaultAsync(d => d.UserId == userId, ct);

            var triggers = new List<string> { "general" };
            if (dasha is not null)
            {
                var maha = System.Text.Json.JsonSerializer.Deserialize<List<System.Text.Json.JsonElement>>(dasha.MahaJson)!;
                var antar = System.Text.Json.JsonSerializer.Deserialize<List<System.Text.Json.JsonElement>>(dasha.AntarJson)!;
                var currentMaha = maha.FirstOrDefault(p => p.GetProperty("current").GetBoolean());
                var currentAntar = antar.FirstOrDefault(p => p.GetProperty("current").GetBoolean());
                if (currentMaha.ValueKind == System.Text.Json.JsonValueKind.Object)
                {
                    triggers.Add(currentMaha.GetProperty("lord").GetString()!);
                }
                if (currentAntar.ValueKind == System.Text.Json.JsonValueKind.Object)
                {
                    triggers.Add(currentAntar.GetProperty("lord").GetString()!);
                }
            }

            var remedies = await db.RemedyContent
                .Where(r => triggers.Contains(r.TriggerRule))
                .ToListAsync(ct);

            // General first, then Dasha-specific — and stable within each
            // group (seed order) so the list doesn't reshuffle between calls.
            var ordered = remedies
                .OrderBy(r => r.TriggerRule == "general" ? 0 : 1)
                .Select(r => new RemedyResponse(r.Id, r.Type, r.Title, r.Detail, r.TriggerRule, r.AudioUrl));

            return Results.Ok(ordered);
        }).RequireAuthorization();
    }
}

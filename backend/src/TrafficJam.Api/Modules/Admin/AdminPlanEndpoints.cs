using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;

namespace TrafficJam.Api.Modules.Admin;

public record AdminUpdateConsultPlanRequest(string Name, long PriceRupees, int SlaHours);
public record AdminUpdateSubscriptionPlanRequest(string Name, long PriceRupees, string[] Features);

/// <summary>
/// Pricing management — ConsultPlanRow/SubscriptionPlanRow used to be a
/// static array (Plans.cs) with a comment inviting exactly this change:
/// "Move to a DB-backed, admin-editable table if/when the admin panel
/// (Phase 2) needs to change prices without a redeploy." Only price/name/SLA
/// /features are editable, not Id/Tier/Cycle — changing those would silently
/// break existing Subscriptions rows and Question.Plan references that key
/// off the old slug.
/// </summary>
public static class AdminPlanEndpoints
{
    public static void MapAdminPlanEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/admin/plans").RequireAuthorization("AdminOnly");

        group.MapGet("/consult", async (AppDbContext db, CancellationToken ct) =>
            Results.Ok(await db.ConsultPlanRows.OrderBy(p => p.PriceRupees).ToListAsync(ct)));

        group.MapPut("/consult/{id}", async (string id, AdminUpdateConsultPlanRequest request, AppDbContext db, CancellationToken ct) =>
        {
            var plan = await db.ConsultPlanRows.SingleOrDefaultAsync(p => p.Id == id, ct);
            if (plan is null) return Results.NotFound();

            plan.Name = request.Name;
            plan.PriceRupees = request.PriceRupees;
            plan.SlaHours = request.SlaHours;
            await db.SaveChangesAsync(ct);
            return Results.Ok(plan);
        });

        group.MapGet("/subscription", async (AppDbContext db, CancellationToken ct) =>
        {
            var plans = await db.SubscriptionPlanRows.OrderBy(p => p.PriceRupees).ToListAsync(ct);
            return Results.Ok(plans.Select(p => new
            {
                p.Id, p.Name, p.Tier, p.Cycle, p.PriceRupees,
                Features = JsonSerializer.Deserialize<string[]>(p.FeaturesJson),
            }));
        });

        group.MapPut("/subscription/{id}", async (string id, AdminUpdateSubscriptionPlanRequest request, AppDbContext db, CancellationToken ct) =>
        {
            var plan = await db.SubscriptionPlanRows.SingleOrDefaultAsync(p => p.Id == id, ct);
            if (plan is null) return Results.NotFound();

            plan.Name = request.Name;
            plan.PriceRupees = request.PriceRupees;
            plan.FeaturesJson = JsonSerializer.Serialize(request.Features);
            await db.SaveChangesAsync(ct);
            return Results.Ok(new
            {
                plan.Id, plan.Name, plan.Tier, plan.Cycle, plan.PriceRupees,
                Features = request.Features,
            });
        });
    }
}

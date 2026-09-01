using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Infrastructure;

/// <summary>
/// Single place that turns a user's persisted <see cref="Subscription"/> row
/// into a yes/no premium-access check — BACKEND_REQUIREMENTS.md's "Tier
/// gates premium features across the app", which nothing enforced until this
/// was added (SubscriptionPlanRow.FeaturesJson was display copy only, read
/// back verbatim by /subscription but never consulted by any endpoint).
///
/// Requires RenewsAt to still be in the future rather than trusting the Tier
/// column alone, because the hourly "Subscription reconciliation" cron job
/// that's meant to flip lapsed subscribers back to Free
/// (BACKEND_REQUIREMENTS.md's scheduled-jobs table) isn't built yet — without
/// this check here, a subscription that lapsed would keep unlocking premium
/// features forever.
/// </summary>
public static class SubscriptionAccess
{
    public static async Task<bool> HasSagaPlusAsync(this AppDbContext db, Guid userId, CancellationToken ct)
    {
        var record = await db.Subscriptions.SingleOrDefaultAsync(s => s.UserId == userId, ct);
        return record is { Tier: SubscriptionTier.SagaPlus, RenewsAt: not null } && record.RenewsAt >= DateTime.UtcNow;
    }

    /// <summary>
    /// Batch version of the same Tier/Cycle → friendly plan name lookup, for
    /// admin list views (Dashboard's recent questions, the Questions queue)
    /// that need one label per row without an N+1 query per row. Matched
    /// against SubscriptionPlanRows (admin-editable — see
    /// Modules/Admin/AdminPlanEndpoints.cs) rather than hardcoded, so a
    /// renamed/added plan shows up here without a redeploy.
    /// </summary>
    public static async Task<Dictionary<Guid, string>> GetSubscriptionPlanLabelsAsync(
        this AppDbContext db, IEnumerable<Guid> userIds, CancellationToken ct)
    {
        var ids = userIds.Distinct().ToList();
        var subs = await db.Subscriptions.Where(s => ids.Contains(s.UserId)).ToDictionaryAsync(s => s.UserId, ct);
        var planNamesByTierCycle = await db.SubscriptionPlanRows
            .ToDictionaryAsync(p => (p.Tier, p.Cycle), p => p.Name, ct);

        string LabelFor(Guid userId)
        {
            if (!subs.TryGetValue(userId, out var sub))
            {
                return planNamesByTierCycle.GetValueOrDefault(("Free", "None"), "Free");
            }
            return planNamesByTierCycle.GetValueOrDefault((sub.Tier.ToString(), sub.Cycle.ToString()), sub.Tier.ToString());
        }

        return ids.ToDictionary(id => id, LabelFor);
    }
}

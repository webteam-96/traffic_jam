namespace TrafficJam.Api.Modules.Consultation;

public record ConsultPlan(string Id, string Name, long PriceRupees, int SlaHours);
public record SubscriptionPlan(string Id, string Name, string Tier, string Cycle, long PriceRupees, string[] Features);

/// <summary>
/// Static pricing for now — API_REQUIREMENTS.md §2.4/§6.4 say pricing must
/// be server-controlled (not hardcoded in the app), which this satisfies.
/// Move to a DB-backed, admin-editable table if/when the admin panel (Phase
/// 2) needs to change prices without a redeploy.
/// </summary>
public static class Plans
{
    public static readonly ConsultPlan[] ConsultPlans =
    [
        new("standard", "Standard", 99, SlaHours: 4),
        new("priority", "Priority", 299, SlaHours: 1),
    ];

    public static readonly SubscriptionPlan[] SubscriptionPlans =
    [
        new("free", "Free", "Free", "None", 0, ["Daily Traffic Signal", "Basic Panchang"]),
        new("saga_plus_monthly", "Saga+ Monthly", "SagaPlus", "Monthly", 299,
            ["Deep-space transits", "Unlimited Panchang", "Priority Ask Jay"]),
        new("saga_plus_annual", "Saga+ Annual", "SagaPlus", "Yearly", 2999,
            ["Deep-space transits", "Unlimited Panchang", "Priority Ask Jay", "2 months free"]),
    ];
}

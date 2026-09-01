namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// Subscription tier pricing — DB-backed (not a static array) so the admin
/// panel can change price/features without a redeploy. Id is the stable
/// slug ("free", "saga_plus_monthly", ...). Tier/Cycle are stored as plain
/// strings here (not the Subscription entity's enums) since a plan's tier
/// name needs to exist independently of any user actually holding it.
/// </summary>
public class SubscriptionPlanRow
{
    public required string Id { get; set; }
    public required string Name { get; set; }
    public required string Tier { get; set; }
    public required string Cycle { get; set; }
    public required long PriceRupees { get; set; }

    /// <summary>JSON-serialized string[] — MySQL has no native array column type.</summary>
    public required string FeaturesJson { get; set; }
}

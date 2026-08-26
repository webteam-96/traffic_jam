namespace TrafficJam.Api.Data.Entities;

public enum SubscriptionTier
{
    Free,
    SagaPlus,
}

public enum BillingCycle
{
    Monthly,
    Yearly,
}

public class Subscription
{
    public Guid UserId { get; set; }
    public SubscriptionTier Tier { get; set; } = SubscriptionTier.Free;
    public BillingCycle Cycle { get; set; } = BillingCycle.Monthly;
    public DateTime? RenewsAt { get; set; }

    /// <summary>Payment gateway's reference id for this subscription (Razorpay/Stripe).</summary>
    public string? GatewayRef { get; set; }

    public User User { get; set; } = null!;
}

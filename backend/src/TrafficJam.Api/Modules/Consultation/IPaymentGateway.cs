namespace TrafficJam.Api.Modules.Consultation;

/// <summary>
/// Razorpay/Stripe abstraction — BACKEND_REQUIREMENTS.md §1.5. Used by both
/// Ask Jay checkout and Subscription checkout/verify.
/// </summary>
public interface IPaymentGateway
{
    Task<PaymentOrder> CreateOrderAsync(long amountPaise, string currency, string receipt, CancellationToken cancellationToken = default);
    Task<bool> VerifyPaymentAsync(string orderId, string paymentId, string signature, CancellationToken cancellationToken = default);
}

public record PaymentOrder(string OrderId, long AmountPaise, string Currency);

public class PaymentGatewayNotConfiguredException(string message) : Exception(message);

/// <summary>Throws a clear, actionable error until a real gateway (Razorpay/Stripe) is wired in.</summary>
public class NotConfiguredPaymentGateway : IPaymentGateway
{
    public Task<PaymentOrder> CreateOrderAsync(long amountPaise, string currency, string receipt, CancellationToken cancellationToken = default) =>
        throw new PaymentGatewayNotConfiguredException(
            "No payment gateway is configured yet — set Payments:Provider (razorpay/stripe) and its " +
            "API keys before checkout can be used. See backend/README.md.");

    public Task<bool> VerifyPaymentAsync(string orderId, string paymentId, string signature, CancellationToken cancellationToken = default) =>
        throw new PaymentGatewayNotConfiguredException(
            "No payment gateway is configured yet — set Payments:Provider (razorpay/stripe) and its " +
            "API keys before payment verification can be used. See backend/README.md.");
}

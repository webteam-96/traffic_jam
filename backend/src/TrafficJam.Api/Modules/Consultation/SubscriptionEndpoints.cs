using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Consultation;

public record SubscriptionResponse(string Tier, string Cycle, DateTime? RenewsAt, string[] Features);
public record CheckoutRequest(string PlanId);
public record CheckoutResponse(string OrderId, long AmountPaise, string Currency);
public record VerifyRequest(string OrderId, string PaymentId, string Signature, string PlanId);

public static class SubscriptionEndpoints
{
    public static void MapSubscriptionEndpoints(this WebApplication app)
    {
        app.MapGet("/subscription/plans", () => Results.Ok(Plans.SubscriptionPlans)).AllowAnonymous();

        var sub = app.MapGroup("/subscription").RequireAuthorization();

        sub.MapGet("/", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var record = await db.Subscriptions.SingleOrDefaultAsync(s => s.UserId == principal.UserId(), ct);
            record ??= new Subscription { UserId = principal.UserId() };

            var plan = Plans.SubscriptionPlans.FirstOrDefault(p => p.Tier == record.Tier.ToString());
            return Results.Ok(new SubscriptionResponse(
                record.Tier.ToString(), record.Cycle.ToString(), record.RenewsAt, plan?.Features ?? []));
        });

        sub.MapPost("/checkout", async (CheckoutRequest request, IPaymentGateway gateway, CancellationToken ct) =>
            await CreateOrderOrCleanErrorAsync(gateway, request.PlanId, ct));

        app.MapPost("/payments/checkout", async (CheckoutRequest request, IPaymentGateway gateway, CancellationToken ct) =>
            await CreateOrderOrCleanErrorAsync(gateway, request.PlanId, ct)).RequireAuthorization();

        sub.MapPost("/verify", async (
            VerifyRequest request, System.Security.Claims.ClaimsPrincipal principal,
            IPaymentGateway gateway, AppDbContext db, CancellationToken ct) =>
        {
            bool verified;
            try
            {
                verified = await gateway.VerifyPaymentAsync(request.OrderId, request.PaymentId, request.Signature, ct);
            }
            catch (PaymentGatewayNotConfiguredException ex)
            {
                return Results.Json(new { error = new { code = "PAYMENTS_NOT_CONFIGURED", message = ex.Message } },
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }

            if (!verified)
            {
                return Results.Json(new { error = new { code = "PAYMENT_NOT_VERIFIED", message = "Payment signature did not verify." } },
                    statusCode: StatusCodes.Status402PaymentRequired);
            }

            var plan = Plans.SubscriptionPlans.SingleOrDefault(p => p.Id == request.PlanId);
            if (plan is null)
            {
                return Results.Json(new { error = new { code = "UNKNOWN_PLAN", message = $"No plan '{request.PlanId}'." } },
                    statusCode: StatusCodes.Status400BadRequest);
            }

            var userId = principal.UserId();
            var record = await db.Subscriptions.SingleOrDefaultAsync(s => s.UserId == userId, ct);
            if (record is null)
            {
                record = new Subscription { UserId = userId };
                db.Subscriptions.Add(record);
            }

            record.Tier = Enum.Parse<SubscriptionTier>(plan.Tier);
            record.Cycle = Enum.Parse<BillingCycle>(plan.Cycle);
            record.RenewsAt = plan.Cycle == "Yearly" ? DateTime.UtcNow.AddYears(1) : DateTime.UtcNow.AddMonths(1);
            record.GatewayRef = request.OrderId;

            await db.SaveChangesAsync(ct);
            return Results.Ok();
        });
    }

    private static async Task<IResult> CreateOrderOrCleanErrorAsync(IPaymentGateway gateway, string planId, CancellationToken ct)
    {
        var plan = Plans.SubscriptionPlans.SingleOrDefault(p => p.Id == planId);
        if (plan is null)
        {
            return Results.Json(new { error = new { code = "UNKNOWN_PLAN", message = $"No plan '{planId}'." } },
                statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            var order = await gateway.CreateOrderAsync(plan.PriceRupees * 100, "INR", $"plan:{plan.Id}", ct);
            return Results.Ok(new CheckoutResponse(order.OrderId, order.AmountPaise, order.Currency));
        }
        catch (PaymentGatewayNotConfiguredException ex)
        {
            return Results.Json(new { error = new { code = "PAYMENTS_NOT_CONFIGURED", message = ex.Message } },
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }
    }
}

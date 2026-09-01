using System.Security.Claims;

namespace TrafficJam.Api.Infrastructure;

public static class ClaimsPrincipalExtensions
{
    /// <summary>The authenticated user's id, from the JWT's NameIdentifier claim.</summary>
    public static Guid UserId(this ClaimsPrincipal principal) =>
        Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new InvalidOperationException("No NameIdentifier claim on the current principal."));

    /// <summary>The authenticated admin's id — same claim, named distinctly at call
    /// sites so an admin endpoint reads as obviously admin-scoped, not user-scoped.</summary>
    public static Guid AdminId(this ClaimsPrincipal principal) => principal.UserId();
}

using System.Security.Claims;

namespace TrafficJam.Api.Infrastructure;

public static class ClaimsPrincipalExtensions
{
    /// <summary>The authenticated user's id, from the JWT's NameIdentifier claim.</summary>
    public static Guid UserId(this ClaimsPrincipal principal) =>
        Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new InvalidOperationException("No NameIdentifier claim on the current principal."));
}

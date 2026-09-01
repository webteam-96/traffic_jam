using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Auth;

public interface IJwtService
{
    /// <summary>Issues a short-lived signed app JWT for the given user.</summary>
    string IssueAccessToken(User user);

    /// <summary>
    /// Issues a short-lived signed JWT for an admin-panel login, carrying a
    /// "role"="admin" claim a regular user's token never has (and vice
    /// versa) — see ClaimsPrincipalExtensions.RequireAdminRole and
    /// Program.cs's "AdminOnly" policy.
    /// </summary>
    string IssueAdminAccessToken(AdminUser admin);

    /// <summary>
    /// Issues a new opaque refresh token. Returns the raw token (given to the
    /// client, never stored) and its hash (what actually goes in the database) —
    /// same never-store-the-raw-value principle as <see cref="PhoneHasher"/>.
    /// </summary>
    RefreshTokenIssued IssueRefreshToken();

    string HashRefreshToken(string rawToken);
}

public record RefreshTokenIssued(string RawToken, string Hash, DateTime ExpiresAt);

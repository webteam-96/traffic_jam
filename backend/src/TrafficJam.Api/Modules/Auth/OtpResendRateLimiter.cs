using Microsoft.Extensions.Caching.Memory;

namespace TrafficJam.Api.Modules.Auth;

/// <summary>
/// Server-side cooldown ledger for the "Resend in 0:28" timer —
/// API_REQUIREMENTS.md §1.3 calls this optional since Firebase also
/// rate-limits, but it gives the app a fast, predictable answer without a
/// round trip to Firebase. Purely ephemeral (no audit value), so an
/// in-memory cache is enough — no database table needed.
/// </summary>
public class OtpResendRateLimiter(IMemoryCache cache)
{
    private static readonly TimeSpan Cooldown = TimeSpan.FromSeconds(30);

    /// <summary>Returns null if a resend is allowed now, or the remaining cooldown otherwise.</summary>
    public TimeSpan? CheckAndRecord(string phoneHash)
    {
        var key = $"otp-resend:{phoneHash}";
        if (cache.TryGetValue<DateTime>(key, out var allowedAt) && allowedAt > DateTime.UtcNow)
        {
            return allowedAt - DateTime.UtcNow;
        }

        cache.Set(key, DateTime.UtcNow.Add(Cooldown), Cooldown);
        return null;
    }
}

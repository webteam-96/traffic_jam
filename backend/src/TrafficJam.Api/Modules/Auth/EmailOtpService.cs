using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Auth;

public enum EmailOtpVerifyResult
{
    Ok,
    /// <summary>No live code for that address — never issued, already used, or expired.</summary>
    NoLiveCode,
    WrongCode,
    /// <summary>Too many wrong guesses; the code is burned and a new one is needed.</summary>
    TooManyAttempts,
}

public interface IEmailOtpService
{
    Task IssueAsync(string email, CancellationToken ct);
    Task<EmailOtpVerifyResult> VerifyAsync(string email, string code, CancellationToken ct);
}

/// <summary>
/// Generates, sends and verifies email sign-in codes — the replacement for
/// Firebase phone OTP, built here rather than bought so there is no dependency
/// on a provider while the user base is small.
///
/// The security properties that matter, and why:
///
///   Codes are stored hashed, salted per address. The table is then useless to
///   anyone who reads it — a leaked backup does not hand over sign-in.
///
///   Codes are random from a CSPRNG, not Random. A predictable code is not a
///   code.
///
///   Five wrong guesses burns it. Six digits is a million possibilities, but
///   only if guessing is expensive; unlimited attempts inside a ten-minute
///   window is not.
///
///   One live code per address. Requesting again invalidates the previous one,
///   so a stack of valid codes can never accumulate.
///
///   Single use. Accepting a code marks it consumed in the same transaction,
///   so it cannot be replayed.
/// </summary>
public class EmailOtpService(
    AppDbContext db,
    IEmailSender emailSender,
    ILogger<EmailOtpService> logger) : IEmailOtpService
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(10);
    private const int MaxAttempts = 5;

    public async Task IssueAsync(string email, CancellationToken ct)
    {
        var normalised = EmailHasher.Normalise(email);
        var emailHash = EmailHasher.Hash(normalised);
        var code = GenerateCode();

        // Any earlier code for this address stops working the moment a new one
        // is issued — otherwise requesting three codes would leave three valid.
        await db.EmailOtps
            .Where(o => o.EmailHash == emailHash && o.ConsumedAt == null)
            .ExecuteUpdateAsync(o => o.SetProperty(x => x.ConsumedAt, DateTime.UtcNow), ct);

        db.EmailOtps.Add(new EmailOtp
        {
            EmailHash = emailHash,
            Email = normalised,
            CodeHash = HashCode(code, emailHash),
            ExpiresAt = DateTime.UtcNow.Add(Lifetime),
        });
        await db.SaveChangesAsync(ct);

        var minutes = (int)Lifetime.TotalMinutes;
        await emailSender.SendAsync(
            normalised,
            "Your TrafficJam.Life sign-in code",
            $"""
             Your sign-in code is {code}

             It expires in {minutes} minutes and can be used once.

             If you didn't ask to sign in, you can ignore this email — nobody
             can get into your account without this code.

             — TrafficJam.Life
             """,
            ct);
    }

    public async Task<EmailOtpVerifyResult> VerifyAsync(string email, string code, CancellationToken ct)
    {
        var emailHash = EmailHasher.Hash(email);
        var now = DateTime.UtcNow;

        var otp = await db.EmailOtps
            .Where(o => o.EmailHash == emailHash && o.ConsumedAt == null && o.ExpiresAt > now)
            .OrderByDescending(o => o.CreatedAt)
            .FirstOrDefaultAsync(ct);

        if (otp is null) return EmailOtpVerifyResult.NoLiveCode;

        if (otp.AttemptCount >= MaxAttempts)
        {
            // Burn it rather than leaving it sitting there at the limit.
            otp.ConsumedAt = now;
            await db.SaveChangesAsync(ct);
            return EmailOtpVerifyResult.TooManyAttempts;
        }

        // Fixed-time comparison: a byte-by-byte string compare leaks how much
        // of the code was right through timing.
        var matches = CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(otp.CodeHash),
            Encoding.UTF8.GetBytes(HashCode(code.Trim(), emailHash)));

        if (!matches)
        {
            otp.AttemptCount++;
            await db.SaveChangesAsync(ct);
            return otp.AttemptCount >= MaxAttempts
                ? EmailOtpVerifyResult.TooManyAttempts
                : EmailOtpVerifyResult.WrongCode;
        }

        otp.ConsumedAt = now;
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Email sign-in code verified.");
        return EmailOtpVerifyResult.Ok;
    }

    /// <summary>
    /// Six digits from a CSPRNG, leading zeros preserved — "004821" is as
    /// valid a code as "904821", and dropping the zeros would both shrink the
    /// space and confuse anyone typing what they were sent.
    /// </summary>
    private static string GenerateCode() =>
        RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    /// <summary>
    /// Salted with the address hash so the same code issued to two people
    /// stores differently, and so a precomputed table of all million digests
    /// is worthless.
    /// </summary>
    private static string HashCode(string code, string emailHash) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes($"{emailHash}:{code}")));
}

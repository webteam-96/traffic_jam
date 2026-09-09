using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Auth;

public record EmailOtpRequest(string Email);
public record EmailOtpVerifyRequest(string Email, string Code);

/// <summary>
/// Email sign-in: `POST /auth/email/request-otp` then
/// `/auth/email/verify-otp`. Codes are generated and checked here rather than
/// by Firebase — see EmailOtpService.
///
/// BUILT BUT NOT YET THE APP'S SIGN-IN METHOD. The Flutter app still uses
/// phone OTP; these endpoints exist so email can be exercised and reviewed
/// before it replaces that. Switching over means pointing the login screen at
/// these two routes — nothing here needs to change.
///
/// Both endpoints are deliberately vague about whether an account exists.
/// "That address has no account" tells a stranger which of your users are
/// registered, so requesting a code for an unknown address succeeds exactly
/// like a known one, and verification's failures don't distinguish between
/// "wrong code" and "no such address".
/// </summary>
public static class EmailAuthEndpoints
{
    public static void MapEmailAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/auth/email");

        group.MapPost("/request-otp", async (
            EmailOtpRequest request,
            IEmailOtpService otpService,
            OtpResendRateLimiter rateLimiter,
            ILoggerFactory loggerFactory,
            CancellationToken ct) =>
        {
            if (!EmailHasher.LooksValid(request.Email))
            {
                return Results.BadRequest(new
                {
                    error = new { code = "INVALID_EMAIL", message = "That doesn't look like an email address." },
                });
            }

            // Same cooldown ledger the phone flow uses, keyed by the address
            // hash. Without it, one endpoint call is one email — a free way to
            // flood someone's inbox, and a fast way to burn a sending
            // reputation.
            var cooldown = rateLimiter.CheckAndRecord($"email:{EmailHasher.Hash(request.Email)}");
            if (cooldown is not null)
            {
                return Results.Json(new
                {
                    error = new
                    {
                        code = "OTP_COOLDOWN",
                        message = $"Please wait {(int)Math.Ceiling(cooldown.Value.TotalSeconds)}s before asking for another code.",
                    },
                }, statusCode: StatusCodes.Status429TooManyRequests);
            }

            try
            {
                await otpService.IssueAsync(request.Email, ct);
            }
            catch (Exception e)
            {
                // A code that was never sent must not look like success — the
                // user would sit waiting for an email that isn't coming.
                loggerFactory.CreateLogger("EmailAuth").LogError(e, "Couldn't issue an email sign-in code.");
                return Results.Json(new
                {
                    error = new { code = "EMAIL_SEND_FAILED", message = "Couldn't send the code. Please try again." },
                }, statusCode: StatusCodes.Status502BadGateway);
            }

            return Results.Ok(new { sent = true });
        }).AllowAnonymous();

        group.MapPost("/verify-otp", async (
            EmailOtpVerifyRequest request,
            IEmailOtpService otpService,
            IJwtService jwt,
            AppDbContext db,
            CancellationToken ct) =>
        {
            var result = await otpService.VerifyAsync(request.Email, request.Code, ct);

            if (result is not EmailOtpVerifyResult.Ok)
            {
                var (code, message) = result switch
                {
                    EmailOtpVerifyResult.TooManyAttempts =>
                        ("TOO_MANY_ATTEMPTS", "Too many wrong tries. Ask for a new code."),
                    // "No live code" and "wrong code" share a message on
                    // purpose: separating them says whether a code was ever
                    // requested for that address.
                    _ => ("INVALID_CODE", "That code isn't right, or it has expired."),
                };

                return Results.Json(new { error = new { code, message } },
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            return Results.Ok(await IssueEmailSessionAsync(request.Email, jwt, db, ct));
        }).AllowAnonymous();
    }

    /// <summary>
    /// Finds or creates the account behind a verified address, then issues the
    /// same token pair phone sign-in does — one session shape, whichever way
    /// the person got here.
    ///
    /// FirebaseUid is reused as the generic auth-identity column ("email:...")
    /// rather than adding a parallel one: it is already the unique key every
    /// other sign-in path writes, and a second identity column would mean two
    /// places to keep in step. Worth renaming when Firebase finally goes.
    /// </summary>
    private static async Task<SessionResponse> IssueEmailSessionAsync(
        string email, IJwtService jwt, AppDbContext db, CancellationToken ct)
    {
        var normalised = EmailHasher.Normalise(email);
        var emailHash = EmailHasher.Hash(normalised);
        var authUid = $"email:{emailHash}";

        var user = await db.Users.SingleOrDefaultAsync(u => u.EmailHash == emailHash, ct);
        if (user is null)
        {
            user = new User
            {
                FirebaseUid = authUid,
                EmailHash = emailHash,
                Email = normalised,
                // PhoneHash is non-nullable and unique, and an email-only
                // account has no number. A per-account placeholder keyed off
                // the email keeps the column unique without inventing a phone
                // number that could collide with a real one.
                PhoneHash = $"email-only:{emailHash}",
            };
            db.Users.Add(user);
        }
        else
        {
            // Keeps the readable address in step with the hash it was matched
            // on, the same way phone sign-in refreshes Phone.
            user.Email = normalised;
        }

        // Saved before issuing so a brand-new account has its Id.
        await db.SaveChangesAsync(ct);

        var accessToken = jwt.IssueAccessToken(user);
        var refresh = jwt.IssueRefreshToken();
        db.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = refresh.Hash,
            ExpiresAt = refresh.ExpiresAt,
        });
        await db.SaveChangesAsync(ct);

        return new SessionResponse(accessToken, refresh.RawToken, 15 * 60);
    }
}

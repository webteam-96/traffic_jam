using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Auth;

public record SessionRequest(string FirebaseIdToken);
public record SessionResponse(string AccessToken, string RefreshToken, int ExpiresInSeconds);
public record RefreshRequest(string RefreshToken);
public record OtpResendRequest(string PhoneNumber);
public record OtpResendResponse(bool Allowed, int RetryAfterSeconds);
public record MeResponse(Guid Id, string? Name, string? AvatarUrl, bool OnboardingComplete);
public record ConfigResponse(string MinSupportedBuild, bool ForceUpdate, Dictionary<string, bool> FeatureFlags);
public record DevLoginRequest(string PhoneNumber, string Otp);

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var auth = app.MapGroup("/auth");

        auth.MapPost("/session", async (
            SessionRequest request,
            IFirebaseTokenVerifier verifier,
            IJwtService jwt,
            AppDbContext db,
            CancellationToken ct) =>
        {
            FirebaseVerifiedToken verified;
            try
            {
                verified = await verifier.VerifyAsync(request.FirebaseIdToken, ct);
            }
            catch (InvalidFirebaseTokenException ex)
            {
                return Results.Json(new { error = new { code = "INVALID_TOKEN", message = ex.Message } },
                    statusCode: StatusCodes.Status401Unauthorized);
            }
            catch (FirebaseNotConfiguredException ex)
            {
                return Results.Json(new { error = new { code = "AUTH_NOT_CONFIGURED", message = ex.Message } },
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }

            var response = await IssueSessionAsync(verified.Uid, verified.PhoneNumber, jwt, db, ct);
            return Results.Ok(response);
        });

        // Dev-only stand-in for real Firebase phone-OTP, so the app can be built and
        // tested end-to-end before a real Firebase project exists. Fixed OTP, any
        // phone number — gated entirely behind Auth:DevModeEnabled (see Program.cs;
        // refuses to start if that's ever true outside Development).
        auth.MapPost("/dev-login", async (
            DevLoginRequest request,
            IConfiguration configuration,
            IJwtService jwt,
            AppDbContext db,
            CancellationToken ct) =>
        {
            if (!configuration.GetValue<bool>("Auth:DevModeEnabled"))
            {
                return Results.NotFound();
            }

            const string devOtp = "123456";
            if (request.Otp != devOtp)
            {
                return Results.Json(new { error = new { code = "INVALID_OTP", message = $"Dev mode OTP is always '{devOtp}'." } },
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            // Synthetic Firebase UID derived from the phone, so the same dummy number
            // always maps to the same dev user across app launches.
            var devUid = $"dev:{request.PhoneNumber}";
            var response = await IssueSessionAsync(devUid, request.PhoneNumber, jwt, db, ct);
            return Results.Ok(response);
        }).AllowAnonymous();

        auth.MapPost("/refresh", async (
            RefreshRequest request,
            IJwtService jwt,
            AppDbContext db,
            CancellationToken ct) =>
        {
            var hash = jwt.HashRefreshToken(request.RefreshToken);
            var stored = await db.RefreshTokens
                .Include(r => r.User)
                .SingleOrDefaultAsync(r => r.TokenHash == hash, ct);

            if (stored is null || stored.RevokedAt is not null || stored.ExpiresAt < DateTime.UtcNow)
            {
                return Results.Json(new { error = new { code = "INVALID_REFRESH_TOKEN", message = "Refresh token is invalid or expired." } },
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            // Rotate: revoke the redeemed token, issue a fresh pair.
            stored.RevokedAt = DateTime.UtcNow;
            var newRefresh = jwt.IssueRefreshToken();
            db.RefreshTokens.Add(new RefreshToken
            {
                UserId = stored.UserId,
                TokenHash = newRefresh.Hash,
                ExpiresAt = newRefresh.ExpiresAt,
            });
            var accessToken = jwt.IssueAccessToken(stored.User);

            await db.SaveChangesAsync(ct);

            return Results.Ok(new SessionResponse(accessToken, newRefresh.RawToken, 15 * 60));
        });

        auth.MapPost("/otp/resend", (OtpResendRequest request, OtpResendRateLimiter limiter) =>
        {
            var remaining = limiter.CheckAndRecord(PhoneHasher.Hash(request.PhoneNumber));
            return remaining is null
                ? Results.Ok(new OtpResendResponse(true, 0))
                : Results.Ok(new OtpResendResponse(false, (int)Math.Ceiling(remaining.Value.TotalSeconds)));
        });

        app.MapGet("/me", async (System.Security.Claims.ClaimsPrincipal user, AppDbContext db, CancellationToken ct) =>
        {
            var userId = user.UserId();
            var record = await db.Users
                .Include(u => u.BirthData)
                .SingleOrDefaultAsync(u => u.Id == userId, ct);

            if (record is null) return Results.NotFound();

            return Results.Ok(new MeResponse(record.Id, record.Name, record.AvatarUrl, record.BirthData is not null));
        }).RequireAuthorization();

        app.MapGet("/config", (IConfiguration configuration) =>
        {
            return Results.Ok(new ConfigResponse(
                MinSupportedBuild: configuration["App:MinSupportedBuild"] ?? "1.0.0",
                ForceUpdate: false,
                FeatureFlags: new Dictionary<string, bool>()));
        }).AllowAnonymous();
    }

    /// <summary>
    /// The identity-resolution + token-issuance logic shared by real Firebase
    /// sessions and dev-mode logins: find-or-create the user by UID (re-linking
    /// by phone if the UID is new — see the comment at the call site), issue a
    /// fresh access + refresh token pair.
    /// </summary>
    private static async Task<SessionResponse> IssueSessionAsync(
        string authUid, string phoneNumber, IJwtService jwt, AppDbContext db, CancellationToken ct)
    {
        var phoneHash = PhoneHasher.Hash(phoneNumber);

        var user = await db.Users.SingleOrDefaultAsync(u => u.FirebaseUid == authUid, ct);
        if (user is null)
        {
            // The same phone number can come back under a *different* auth UID
            // (reinstall, re-verification, SIM swap) — PhoneHash is unique, so treat
            // that as the same person and re-link, rather than trying to insert a
            // second row and crashing on the unique-index violation.
            user = await db.Users.SingleOrDefaultAsync(u => u.PhoneHash == phoneHash, ct);
            if (user is not null)
            {
                user.FirebaseUid = authUid;
            }
            else
            {
                user = new User { FirebaseUid = authUid, PhoneHash = phoneHash };
                db.Users.Add(user);
            }
        }

        // Sign-in is the only moment the raw number passes through, so it's
        // also the only chance to fill it in for accounts that predate the
        // column (their number exists solely as an unreversible hash). Set
        // unconditionally rather than only-when-null so a re-verified number
        // stays in step with the hash it's being matched against.
        user.Phone = phoneNumber;

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

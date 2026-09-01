using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;
using TrafficJam.Api.Modules.Auth;

namespace TrafficJam.Api.Modules.Admin;

public record AdminLoginRequest(string Email, string Password);
public record AdminLoginResponse(string AccessToken, string Name, string Email);
public record AdminMeResponse(Guid Id, string Name, string Email);

public static class AdminAuthEndpoints
{
    public static void MapAdminAuthEndpoints(this WebApplication app)
    {
        app.MapPost("/admin/auth/login", async (
            AdminLoginRequest request, AppDbContext db, IJwtService jwt, CancellationToken ct) =>
        {
            var admin = await db.AdminUsers.SingleOrDefaultAsync(a => a.Email == request.Email, ct);
            if (admin is null || !AdminPasswordHasher.Verify(request.Password, admin.PasswordHash))
            {
                // Same generic message either way — doesn't reveal whether the
                // email exists, standard login-endpoint practice.
                return Results.Json(new { error = new { code = "INVALID_CREDENTIALS", message = "Incorrect email or password." } },
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var token = jwt.IssueAdminAccessToken(admin);
            return Results.Ok(new AdminLoginResponse(token, admin.Name, admin.Email));
        }).AllowAnonymous();

        app.MapGet("/admin/auth/me", async (
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var admin = await db.AdminUsers.SingleAsync(a => a.Id == principal.AdminId(), ct);
            return Results.Ok(new AdminMeResponse(admin.Id, admin.Name, admin.Email));
        }).RequireAuthorization("AdminOnly");
    }
}

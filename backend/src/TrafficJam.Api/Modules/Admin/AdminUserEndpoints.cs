using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;

namespace TrafficJam.Api.Modules.Admin;

public record AdminUserSummary(Guid Id, string? Name, DateTime CreatedAt, bool HasBirthData, string Tier);
public record AdminUserListResponse(IReadOnlyList<AdminUserSummary> Users, int TotalCount);

public record AdminUserDetail(
    Guid Id, string? Name, DateTime CreatedAt, string Tier,
    string? BirthPlace, DateOnly? Dob, bool? UnknownTime,
    int QuestionCount, int AppointmentCount);

public static class AdminUserEndpoints
{
    public static void MapAdminUserEndpoints(this WebApplication app)
    {
        // Search is name-only — phone numbers are stored as a one-way hash
        // (see User.PhoneHash's doc comment) precisely so they can't be
        // recovered, including by admin tooling. That's a deliberate privacy
        // tradeoff, not an oversight: there is no "look up by phone number"
        // available anywhere in this system, by design.
        app.MapGet("/admin/users", async (string? q, AppDbContext db, CancellationToken ct, int page = 1, int pageSize = 25) =>
        {
            page = page <= 0 ? 1 : page;
            pageSize = pageSize is <= 0 or > 100 ? 25 : pageSize;

            var query = db.Users.AsQueryable();
            if (!string.IsNullOrWhiteSpace(q))
            {
                query = query.Where(u => u.Name != null && u.Name.Contains(q));
            }

            var totalCount = await query.CountAsync(ct);
            var page_ = await query
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(u => new
                {
                    u.Id, u.Name, u.CreatedAt,
                    HasBirthData = u.BirthData != null,
                    Tier = u.Subscription != null ? u.Subscription.Tier.ToString() : "Free",
                })
                .ToListAsync(ct);

            var users = page_.Select(u => new AdminUserSummary(u.Id, u.Name, u.CreatedAt, u.HasBirthData, u.Tier)).ToList();
            return Results.Ok(new AdminUserListResponse(users, totalCount));
        }).RequireAuthorization("AdminOnly");

        app.MapGet("/admin/users/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var user = await db.Users
                .Include(u => u.BirthData)
                .Include(u => u.Subscription)
                .SingleOrDefaultAsync(u => u.Id == id, ct);
            if (user is null) return Results.NotFound();

            var questionCount = await db.Questions.CountAsync(q => q.UserId == id, ct);
            var appointmentCount = await db.Appointments.CountAsync(a => a.UserId == id, ct);

            return Results.Ok(new AdminUserDetail(
                user.Id, user.Name, user.CreatedAt,
                user.Subscription?.Tier.ToString() ?? "Free",
                user.BirthData?.Place, user.BirthData?.Dob, user.BirthData?.UnknownTime,
                questionCount, appointmentCount));
        }).RequireAuthorization("AdminOnly");
    }
}

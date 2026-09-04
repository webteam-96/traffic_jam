using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;

namespace TrafficJam.Api.Modules.Admin;

public record AdminUserSummary(Guid Id, string? Name, DateTime CreatedAt, bool HasBirthData, string Tier);
public record AdminUserListResponse(IReadOnlyList<AdminUserSummary> Users, int TotalCount);

/// <summary>One of this user's consultation bookings, as the person who has
/// to actually run the session needs to see it: when they asked for, what
/// about, and in their own words.</summary>
public record AdminUserBooking(
    Guid Id, string Area, string Email, string? Message,
    DateOnly PreferredDate, TimeOnly PreferredTime, string Status, DateTime CreatedAt);

/// <summary>One of this user's Ask Jay questions — the other place they've
/// told us what they're actually worried about.</summary>
public record AdminUserQuestion(
    Guid Id, string Domain, string Text, string Status, DateTime CreatedAt);

public record AdminUserDetail(
    Guid Id, string? Name, string? Phone, DateTime CreatedAt, string Tier,
    string? BirthPlace, DateOnly? Dob, TimeOnly? Tob, bool? UnknownTime,
    int QuestionCount, int AppointmentCount,
    IReadOnlyList<AdminUserBooking> Bookings,
    IReadOnlyList<AdminUserQuestion> Questions);

public static class AdminUserEndpoints
{
    public static void MapAdminUserEndpoints(this IEndpointRouteBuilder app)
    {
        // Search is name-only. The stored number (User.Phone) is AES-GCM
        // encrypted, so its ciphertext differs on every write and can't be
        // matched by a LIKE/= filter — partial phone search isn't possible
        // without a separate searchable index. An exact-number lookup *would*
        // be possible by hashing the query and matching User.PhoneHash; not
        // built yet, deliberately, rather than half-built here.
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

            // Newest first, and capped: this drawer is for "who am I about to
            // talk to", not an archive. Neither table is encrypted (only
            // BirthData and User.Phone are), so projecting in SQL is fine here
            // — unlike the birth fields above, which have to be materialised.
            var bookings = await db.Appointments
                .Where(a => a.UserId == id)
                .OrderByDescending(a => a.PreferredDate).ThenByDescending(a => a.PreferredTime)
                .Take(20)
                .Select(a => new AdminUserBooking(
                    a.Id, a.Area, a.Email, a.Message,
                    a.PreferredDate, a.PreferredTime, a.Status.ToString(), a.CreatedAt))
                .ToListAsync(ct);

            var questions = await db.Questions
                .Where(q => q.UserId == id)
                .OrderByDescending(q => q.CreatedAt)
                .Take(20)
                .Select(q => new AdminUserQuestion(
                    q.Id, q.Domain, q.Text, q.Status.ToString(), q.CreatedAt))
                .ToListAsync(ct);

            var questionCount = await db.Questions.CountAsync(q => q.UserId == id, ct);
            var appointmentCount = await db.Appointments.CountAsync(a => a.UserId == id, ct);

            return Results.Ok(new AdminUserDetail(
                user.Id, user.Name, user.Phone, user.CreatedAt,
                user.Subscription?.Tier.ToString() ?? "Free",
                user.BirthData?.Place, user.BirthData?.Dob, user.BirthData?.Tob, user.BirthData?.UnknownTime,
                questionCount, appointmentCount, bookings, questions));
        }).RequireAuthorization("AdminOnly");
    }
}

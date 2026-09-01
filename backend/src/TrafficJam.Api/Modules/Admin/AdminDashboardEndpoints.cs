using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Admin;

public record AdminDashboardSummary(
    int TotalUsers, int UsersWithBirthData, int NewUsersLast7Days,
    int PendingQuestions, int AnsweredQuestions,
    int PendingAppointments,
    int PayingSubscribers,
    IReadOnlyList<AdminRecentQuestion> RecentQuestions);

public record AdminRecentQuestion(
    Guid Id, string? UserName, string Domain, string Question, string Status, DateTime CreatedAt, string SubscriptionPlanName);

public static class AdminDashboardEndpoints
{
    public static void MapAdminDashboardEndpoints(this WebApplication app)
    {
        app.MapGet("/admin/dashboard/summary", async (AppDbContext db, CancellationToken ct) =>
        {
            var sevenDaysAgo = DateTime.UtcNow.AddDays(-7);

            var totalUsers = await db.Users.CountAsync(ct);
            var usersWithBirthData = await db.BirthData.CountAsync(ct);
            var newUsers = await db.Users.CountAsync(u => u.CreatedAt >= sevenDaysAgo, ct);
            var pendingQuestions = await db.Questions.CountAsync(q => q.Status == QuestionStatus.Pending, ct);
            var answeredQuestions = await db.Questions.CountAsync(q => q.Status == QuestionStatus.Answered, ct);
            var pendingAppointments = await db.Appointments.CountAsync(a => a.Status == AppointmentStatus.Pending, ct);
            var payingSubscribers = await db.Subscriptions.CountAsync(s => s.Tier != SubscriptionTier.Free, ct);

            var recentQuestions = await db.Questions
                .Include(q => q.User)
                .OrderByDescending(q => q.CreatedAt)
                .Take(6)
                .ToListAsync(ct);

            var planLabels = await db.GetSubscriptionPlanLabelsAsync(recentQuestions.Select(q => q.UserId), ct);

            var recent = recentQuestions
                .Select(q => new AdminRecentQuestion(q.Id, q.User.Name, q.Domain, q.Text, q.Status.ToString(), q.CreatedAt, planLabels[q.UserId]))
                .ToList();

            return Results.Ok(new AdminDashboardSummary(
                totalUsers, usersWithBirthData, newUsers,
                pendingQuestions, answeredQuestions,
                pendingAppointments, payingSubscribers,
                recent));
        }).RequireAuthorization("AdminOnly");
    }
}

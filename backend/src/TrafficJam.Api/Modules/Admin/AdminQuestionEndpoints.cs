using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Admin;

public record AdminQuestionSummary(
    Guid Id, string? UserName, string Domain, string Question, string Plan, string SubscriptionPlanName,
    string Status, DateTime SlaAt, DateTime CreatedAt);

public record AdminQuestionDetail(
    Guid Id, string? UserName, string Domain, string Question, string Plan, string SubscriptionPlanName,
    string Status, DateTime SlaAt, DateTime CreatedAt,
    JsonElement Context, IReadOnlyList<AdminMessage> Messages);

public record AdminMessage(Guid Id, string Sender, string Text, DateTime CreatedAt);
public record AdminReplyRequest(string Text);

/// <summary>
/// Ask Jay's admin side — the queue of real questions, each with the real
/// context snapshot ConsultationEndpoints.BuildContextSnapshotAsync already
/// attached, and the one endpoint (POST .../reply) that finally lets
/// someone answer as MessageSender.Astrologer — that enum value has existed
/// since Question/Message were built, but nothing could ever set it before
/// this admin panel existed.
/// </summary>
public static class AdminQuestionEndpoints
{
    public static void MapAdminQuestionEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/admin/questions", async (string? status, AppDbContext db, CancellationToken ct, int page = 1, int pageSize = 25) =>
        {
            page = page <= 0 ? 1 : page;
            pageSize = pageSize is <= 0 or > 100 ? 25 : pageSize;

            var query = db.Questions.Include(q => q.User).AsQueryable();
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<QuestionStatus>(status, true, out var parsed))
            {
                query = query.Where(q => q.Status == parsed);
            }

            var totalCount = await query.CountAsync(ct);
            var page_ = await query
                .OrderBy(q => q.Status == QuestionStatus.Pending ? 0 : 1) // pending first
                .ThenBy(q => q.SlaAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .ToListAsync(ct);

            var planLabels = await db.GetSubscriptionPlanLabelsAsync(page_.Select(q => q.UserId), ct);
            var questions = page_
                .Select(q => new AdminQuestionSummary(
                    q.Id, q.User.Name, q.Domain, q.Text, q.Plan, planLabels[q.UserId], q.Status.ToString(), q.SlaAt, q.CreatedAt))
                .ToList();

            return Results.Ok(new { questions, totalCount });
        }).RequireAuthorization("AdminOnly");

        app.MapGet("/admin/questions/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var q = await db.Questions.Include(x => x.User).Include(x => x.Messages)
                .SingleOrDefaultAsync(x => x.Id == id, ct);
            if (q is null) return Results.NotFound();

            var messages = q.Messages.OrderBy(m => m.CreatedAt)
                .Select(m => new AdminMessage(m.Id, m.Sender.ToString().ToLowerInvariant(), m.Text, m.CreatedAt))
                .ToList();

            var planLabels = await db.GetSubscriptionPlanLabelsAsync([q.UserId], ct);

            return Results.Ok(new AdminQuestionDetail(
                q.Id, q.User.Name, q.Domain, q.Text, q.Plan, planLabels[q.UserId], q.Status.ToString(), q.SlaAt, q.CreatedAt,
                JsonSerializer.Deserialize<JsonElement>(q.ContextJson), messages));
        }).RequireAuthorization("AdminOnly");

        app.MapPost("/admin/questions/{id:guid}/reply", async (
            Guid id, AdminReplyRequest request, AppDbContext db, CancellationToken ct) =>
        {
            var question = await db.Questions.SingleOrDefaultAsync(x => x.Id == id, ct);
            if (question is null) return Results.NotFound();

            var message = new Message { QuestionId = id, Sender = MessageSender.Astrologer, Text = request.Text };
            db.Messages.Add(message);
            if (question.Status == QuestionStatus.Pending)
            {
                question.Status = QuestionStatus.Answered;
            }

            await db.SaveChangesAsync(ct);
            return Results.Ok(new AdminMessage(message.Id, "astrologer", message.Text, message.CreatedAt));
        }).RequireAuthorization("AdminOnly");

        app.MapPost("/admin/questions/{id:guid}/close", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var question = await db.Questions.SingleOrDefaultAsync(x => x.Id == id, ct);
            if (question is null) return Results.NotFound();

            question.Status = QuestionStatus.Closed;
            await db.SaveChangesAsync(ct);
            return Results.Ok();
        }).RequireAuthorization("AdminOnly");
    }
}

using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Consultation;

public record AskQuestionRequest(string Domain, string Question, string PlanId);
public record AskQuestionResponse(Guid QuestionId, DateTime Sla);
public record QuestionSummary(Guid Id, string Domain, string Question, string Status, DateTime CreatedAt);
public record SendMessageRequest(string Text);
public record MessageResponse(Guid Id, string Sender, string Text, DateTime CreatedAt);

public static class ConsultationEndpoints
{
    public static void MapConsultationEndpoints(this WebApplication app)
    {
        app.MapGet("/consult/plans", () => Results.Ok(Plans.ConsultPlans)).AllowAnonymous();

        var consult = app.MapGroup("/consult").RequireAuthorization();

        consult.MapPost("/questions", async (
            AskQuestionRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var plan = Plans.ConsultPlans.SingleOrDefault(p => p.Id == request.PlanId);
            if (plan is null)
            {
                return Results.Json(new { error = new { code = "UNKNOWN_PLAN", message = $"No plan '{request.PlanId}'." } },
                    statusCode: StatusCodes.Status400BadRequest);
            }

            // TODO(astro-engine): once chart/dasha/transits/panchang exist, attach a
            // real context snapshot here (BACKEND_REQUIREMENTS.md — Ask Jay is
            // "CRUD + context join"). Empty object until then, not fabricated data.
            var question = new Question
            {
                UserId = principal.UserId(),
                Domain = request.Domain,
                Text = request.Question,
                ContextJson = "{}",
                Plan = plan.Id,
                SlaAt = DateTime.UtcNow.AddHours(plan.SlaHours),
            };
            db.Questions.Add(question);
            await db.SaveChangesAsync(ct);

            return Results.Ok(new AskQuestionResponse(question.Id, question.SlaAt));
        });

        consult.MapGet("/questions", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var results = await db.Questions
                .Where(q => q.UserId == principal.UserId())
                .OrderByDescending(q => q.CreatedAt)
                .Select(q => new QuestionSummary(q.Id, q.Domain, q.Text, q.Status.ToString().ToLower(), q.CreatedAt))
                .ToListAsync(ct);

            return Results.Ok(results);
        });

        consult.MapGet("/questions/{id:guid}/messages", async (
            Guid id, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var owns = await db.Questions.AnyAsync(q => q.Id == id && q.UserId == principal.UserId(), ct);
            if (!owns) return Results.NotFound();

            var messages = await db.Messages
                .Where(m => m.QuestionId == id)
                .OrderBy(m => m.CreatedAt)
                .Select(m => new MessageResponse(m.Id, m.Sender.ToString().ToLower(), m.Text, m.CreatedAt))
                .ToListAsync(ct);

            return Results.Ok(messages);
        });

        consult.MapPost("/questions/{id:guid}/messages", async (
            Guid id, SendMessageRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var owns = await db.Questions.AnyAsync(q => q.Id == id && q.UserId == principal.UserId(), ct);
            if (!owns) return Results.NotFound();

            var message = new Message { QuestionId = id, Sender = MessageSender.User, Text = request.Text };
            db.Messages.Add(message);
            await db.SaveChangesAsync(ct);

            // TODO(notification-service / realtime): deliver via WebSocket/FCM once
            // that infra exists (API_REQUIREMENTS.md §4.1) — for now the astrologer's
            // reply only shows up on next GET.

            return Results.Ok(new MessageResponse(message.Id, "user", message.Text, message.CreatedAt));
        });
    }
}

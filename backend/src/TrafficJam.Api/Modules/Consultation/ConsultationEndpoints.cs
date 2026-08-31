using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;
using TrafficJam.Api.Modules.Astro;

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
            AskQuestionRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IPanchangService panchangService, ITransitService transitService, CancellationToken ct) =>
        {
            var plan = Plans.ConsultPlans.SingleOrDefault(p => p.Id == request.PlanId);
            if (plan is null)
            {
                return Results.Json(new { error = new { code = "UNKNOWN_PLAN", message = $"No plan '{request.PlanId}'." } },
                    statusCode: StatusCodes.Status400BadRequest);
            }

            var userId = principal.UserId();
            var contextJson = await BuildContextSnapshotAsync(db, userId, panchangService, transitService, ct);

            var question = new Question
            {
                UserId = userId,
                Domain = request.Domain,
                Text = request.Question,
                ContextJson = contextJson,
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

    /// <summary>
    /// Joins the user's already-computed chart + Dasha (stored, not
    /// recomputed) with a fresh today's Panchang + transits read into one
    /// snapshot for the astrologer answering the question — the "context
    /// join" BACKEND_REQUIREMENTS.md describes for Ask Jay. Returns "{}"
    /// (not fabricated placeholder data) when the user hasn't saved birth
    /// data yet, so the question still gets created — just with no chart
    /// context attached, the same graceful-degradation the rest of the Astro
    /// Engine uses for missing/unknown birth data.
    /// </summary>
    private static async Task<string> BuildContextSnapshotAsync(
        AppDbContext db, Guid userId, IPanchangService panchangService, ITransitService transitService, CancellationToken ct)
    {
        var chart = await db.Charts.SingleOrDefaultAsync(c => c.UserId == userId, ct);
        var dasha = await db.Dashas.SingleOrDefaultAsync(d => d.UserId == userId, ct);
        var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
        if (chart is null || dasha is null || birthData is null)
        {
            return "{}";
        }

        var d1 = JsonSerializer.Deserialize<JsonElement>(chart.D1Json);
        var planets = d1.GetProperty("planets");
        string SignOf(string planet) => planets.EnumerateArray()
            .Single(p => p.GetProperty("planet").GetString() == planet)
            .GetProperty("sign").GetString()!;
        var moonSignIndex = planets.EnumerateArray()
            .Single(p => p.GetProperty("planet").GetString() == "Moon")
            .GetProperty("signIndex").GetInt32();

        string? CurrentLord(string periodsJson) => JsonSerializer.Deserialize<JsonElement>(periodsJson)
            .EnumerateArray().SingleOrDefault(p => p.GetProperty("current").GetBoolean())
            .GetProperty("lord").GetString();

        var ascendant = d1.GetProperty("ascendant");
        var targetDate = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
            DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));
        var panchang = panchangService.Compute(targetDate, birthData.Lat, birthData.Lng, birthData.Timezone);
        var transits = transitService.Compute(targetDate, natalLagnaSignIndex: null, moonSignIndex);

        var snapshot = new
        {
            chart = new
            {
                ascendantSign = ascendant.TryGetProperty("sign", out var asc) && asc.ValueKind == JsonValueKind.String
                    ? asc.GetString() : null,
                sunSign = SignOf("Sun"),
                moonSign = SignOf("Moon"),
                nakshatra = chart.Nakshatra,
            },
            dasha = new
            {
                maha = CurrentLord(dasha.MahaJson),
                antar = CurrentLord(dasha.AntarJson),
            },
            panchang = new
            {
                tithi = panchang.TithiName,
                nakshatra = panchang.NakshatraName,
                yoga = panchang.YogaName,
                karana = panchang.KaranaName,
            },
            transits = transits.Planets
                .Where(p => p.IsMajor)
                .Select(p => new { planet = p.Planet, houseFromMoon = p.HouseFromMoon }),
        };

        return JsonSerializer.Serialize(snapshot, JsonConventions.CamelCase);
    }
}

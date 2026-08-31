using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// `GET /transits/today` — not named as its own endpoint in API_REQUIREMENTS.md
/// (transits there are a building block consumed by /signal/today, /vibe/today,
/// /insights, and Ask Jay's context-attach, none of which are built yet), but
/// added here the same way other structurally-necessary-but-undocumented
/// endpoints were (see AuthEndpoints' POST /auth/refresh) — there needs to be
/// *some* way to see and test this computation before its consumers exist.
///
/// Cached in Redis per BACKEND_REQUIREMENTS.md's "transits per user:date"
/// caching row — the first real use of Redis in this backend; until now it
/// was only connected and health-checked (see backend/README.md).
/// </summary>
public static class TransitEndpoints
{
    public static void MapTransitEndpoints(this WebApplication app)
    {
        app.MapGet("/transits/today", async (
            DateOnly? date, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IAstroEngineService astroEngine, ITransitService transitService, IConnectionMultiplexer redis, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            if (birthData is null)
            {
                return Results.NotFound(new { error = new { code = "NO_BIRTH_DATA", message = "Save birth data first." } });
            }

            var targetDate = date ?? DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));

            var cacheKey = $"transits:{userId}:{targetDate:yyyy-MM-dd}";
            var redisDb = redis.GetDatabase();
            var cached = await redisDb.StringGetAsync(cacheKey);
            if (cached.HasValue)
            {
                return Results.Content(cached!, "application/json");
            }

            var timeKnown = !birthData.UnknownTime && birthData.Tob is not null;
            var localDateTime = birthData.Dob.ToDateTime(birthData.Tob ?? new TimeOnly(12, 0));
            var tz = TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone);
            var birthUtc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified), tz);

            var natalChart = astroEngine.ComputeBirthChart(birthUtc, birthData.Lat, birthData.Lng, timeKnown);
            var natalLagnaSign = timeKnown ? natalChart.AscendantSignIndex : (int?)null;
            var natalMoonSign = natalChart.D1.Single(p => p.Planet == "Moon").SignIndex;

            var result = transitService.Compute(targetDate, natalLagnaSign, natalMoonSign);

            var json = JsonSerializer.Serialize(result, JsonConventions.CamelCase);
            await redisDb.StringSetAsync(cacheKey, json, TimeSpan.FromHours(26)); // safely spans a full day regardless of when computed
            return Results.Content(json, "application/json");
        }).RequireAuthorization();
    }
}

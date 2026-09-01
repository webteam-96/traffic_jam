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
public record UpcomingTransitEvent(
    string Planet, string FromSign, string ToSign, DateOnly Date, int HouseFromMoon, int? HouseFromLagna);

public static class TransitEndpoints
{
    /// <summary>Slow/notable grahas worth flagging an upcoming sign change
    /// for — Moon (~2.25 days/sign) and Mercury/Venus (fast, frequently
    /// retrograde) change too often to be a meaningful "upcoming event".</summary>
    private static readonly string[] WatchedPlanets = ["Sun", "Mars", "Jupiter", "Saturn", "Rahu", "Ketu"];

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

            TransitResult result;
            if (cached.HasValue)
            {
                result = JsonSerializer.Deserialize<TransitResult>((string)cached!, JsonConventions.CamelCase)!;
            }
            else
            {
                var timeKnown = !birthData.UnknownTime && birthData.Tob is not null;
                var localDateTime = birthData.Dob.ToDateTime(birthData.Tob ?? new TimeOnly(12, 0));
                var tz = TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone);
                var birthUtc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified), tz);

                var natalChart = astroEngine.ComputeBirthChart(birthUtc, birthData.Lat, birthData.Lng, timeKnown);
                var natalLagnaSign = natalChart.AscendantSignIndex;
                var natalMoonSign = natalChart.D1.Single(p => p.Planet == "Moon").SignIndex;

                result = transitService.Compute(targetDate, natalLagnaSign, natalMoonSign);
                await redisDb.StringSetAsync(cacheKey, JsonSerializer.Serialize(result, JsonConventions.CamelCase),
                    TimeSpan.FromHours(26)); // safely spans a full day regardless of when computed
            }

            // "Deep-space transits" (SubscriptionPlanRow's Saga+ feature copy)
            // means the slow-moving outer grahas — exactly GrahaPositions.
            // MajorTransitPlanets, already flagged per-planet as IsMajor. Free
            // tier still gets the fast/personal planets (Sun, Moon, Mars,
            // Mercury, Venus) that day-to-day guidance depends on.
            if (!await db.HasSagaPlusAsync(userId, ct))
            {
                result = result with { Planets = result.Planets.Where(p => !p.IsMajor).ToList() };
            }

            return Results.Content(JsonSerializer.Serialize(result, JsonConventions.CamelCase), "application/json");
        }).RequireAuthorization();

        // `GET /transits/upcoming` — the next sign change ("ingress") for
        // each of WatchedPlanets, scanned forward day-by-day. Saturn's
        // slowest dwell in a sign is under ~2.5 years (~912 days), so a
        // 1,000-day search window guarantees finding every planet's next
        // ingress. No new astro computation needed — ITransitService.Compute
        // already accepts an arbitrary date (see /transits/today above);
        // this just calls it repeatedly and watches for a SignIndex change.
        app.MapGet("/transits/upcoming", async (
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IAstroEngineService astroEngine, ITransitService transitService, IConnectionMultiplexer redis, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            if (birthData is null)
            {
                return Results.NotFound(new { error = new { code = "NO_BIRTH_DATA", message = "Save birth data first." } });
            }

            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));

            var cacheKey = $"transits:upcoming:{userId}:{today:yyyy-MM-dd}";
            var redisDb = redis.GetDatabase();
            var cached = await redisDb.StringGetAsync(cacheKey);

            List<UpcomingTransitEvent> found;
            if (cached.HasValue)
            {
                found = JsonSerializer.Deserialize<List<UpcomingTransitEvent>>((string)cached!, JsonConventions.CamelCase)!;
            }
            else
            {
                var timeKnown = !birthData.UnknownTime && birthData.Tob is not null;
                var localDateTime = birthData.Dob.ToDateTime(birthData.Tob ?? new TimeOnly(12, 0));
                var tz = TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone);
                var birthUtc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified), tz);
                var natalChart = astroEngine.ComputeBirthChart(birthUtc, birthData.Lat, birthData.Lng, timeKnown);
                var natalLagnaSign = natalChart.AscendantSignIndex;
                var natalMoonSign = natalChart.D1.Single(p => p.Planet == "Moon").SignIndex;

                var lastSign = new Dictionary<string, int>();
                var todayResult = transitService.Compute(today, natalLagnaSign, natalMoonSign);
                foreach (var planet in WatchedPlanets)
                {
                    lastSign[planet] = todayResult.Planets.Single(t => t.Planet == planet).SignIndex;
                }

                found = [];
                var pending = new HashSet<string>(WatchedPlanets);
                for (var i = 1; i <= 1000 && pending.Count > 0; i++)
                {
                    var date = today.AddDays(i);
                    var result = transitService.Compute(date, natalLagnaSign, natalMoonSign);
                    foreach (var planet in pending.ToList())
                    {
                        var pos = result.Planets.Single(t => t.Planet == planet);
                        if (pos.SignIndex != lastSign[planet])
                        {
                            found.Add(new UpcomingTransitEvent(
                                planet, VedicMath.SignNames[lastSign[planet]], VedicMath.SignNames[pos.SignIndex],
                                date, pos.HouseFromMoon, pos.HouseFromLagna));
                            pending.Remove(planet);
                        }
                        lastSign[planet] = pos.SignIndex;
                    }
                }

                found.Sort((a, b) => a.Date.CompareTo(b.Date));
                await redisDb.StringSetAsync(cacheKey, JsonSerializer.Serialize(found, JsonConventions.CamelCase),
                    TimeSpan.FromHours(26));
            }

            // Same Free/Saga+ "deep-space transits" split as /transits/today —
            // hide ingress events for the major/slow grahas unless subscribed.
            if (!await db.HasSagaPlusAsync(userId, ct))
            {
                found = found.Where(e => !GrahaPositions.MajorTransitPlanets.Contains(e.Planet)).ToList();
            }

            return Results.Content(JsonSerializer.Serialize(found, JsonConventions.CamelCase), "application/json");
        }).RequireAuthorization();
    }
}

using System.Text.Json;
using Microsoft.EntityFrameworkCore;
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
/// Not cached: this is pure in-memory ephemeris math (no I/O). A Redis cache
/// here was tried and reverted — see the "why not Redis" note in
/// backend/README.md — a real production outage traced to it: this endpoint
/// (and PUT /me/birth-data's cache invalidation, and the /health check) all
/// hung for 8-19s and then 500'd because production's Redis was unreachable.
/// </summary>
public record UpcomingTransitEvent(
    string Planet, string FromSign, string ToSign, DateOnly Date, int HouseFromMoon, int? HouseFromLagna);

public static class TransitEndpoints
{
    /// <summary>Slow/notable grahas worth flagging an upcoming sign change
    /// for — Moon (~2.25 days/sign) and Mercury/Venus (fast, frequently
    /// retrograde) change too often to be a meaningful "upcoming event".</summary>
    private static readonly string[] WatchedPlanets = ["Sun", "Mars", "Jupiter", "Saturn", "Rahu", "Ketu"];

    public static void MapTransitEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/transits/today", async (
            DateOnly? date, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IAstroEngineService astroEngine, ITransitService transitService, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            if (birthData is null)
            {
                return Results.NotFound(new { error = new { code = "NO_BIRTH_DATA", message = "Save birth data first." } });
            }

            var targetDate = date ?? DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));

            var timeKnown = !birthData.UnknownTime && birthData.Tob is not null;
            var localDateTime = birthData.Dob.ToDateTime(birthData.Tob ?? new TimeOnly(12, 0));
            var tz = TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone);
            var birthUtc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified), tz);

            var natalChart = astroEngine.ComputeBirthChart(birthUtc, birthData.Lat, birthData.Lng, timeKnown);
            var natalLagnaSign = natalChart.AscendantSignIndex;
            var natalMoonSign = natalChart.D1.Single(p => p.Planet == "Moon").SignIndex;

            var result = transitService.Compute(targetDate, natalLagnaSign, natalMoonSign);

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
            IAstroEngineService astroEngine, ITransitService transitService, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            if (birthData is null)
            {
                return Results.NotFound(new { error = new { code = "NO_BIRTH_DATA", message = "Save birth data first." } });
            }

            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));

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

            var found = new List<UpcomingTransitEvent>();
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

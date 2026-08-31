using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// `GET /chart` and `GET /dasha` — read-only access to the chart/Dasha data
/// `PUT /me/birth-data` already computes and stores. Neither existed before
/// (the app only ever wrote this data, never had a way to read it back),
/// which blocked wiring the Kundli/Dasha screens to anything real.
/// </summary>
public static class ChartEndpoints
{
    public static void MapChartEndpoints(this WebApplication app)
    {
        app.MapGet("/chart", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var chart = await db.Charts.SingleOrDefaultAsync(c => c.UserId == principal.UserId(), ct);
            if (chart is null)
            {
                return Results.NotFound(new { error = new { code = "NO_CHART", message = "Save birth data first." } });
            }

            var d1 = JsonSerializer.Deserialize<JsonElement>(chart.D1Json);
            var response = new
            {
                ayanamsa = chart.Ayanamsa,
                nakshatra = chart.Nakshatra,
                computedAt = chart.ComputedAt,
                ascendant = d1.GetProperty("ascendant"),
                d1 = d1.GetProperty("planets"),
                d9 = JsonSerializer.Deserialize<JsonElement>(chart.D9Json),
                d10 = JsonSerializer.Deserialize<JsonElement>(chart.D10Json),
                d60 = JsonSerializer.Deserialize<JsonElement>(chart.D60Json), // parses to an empty array when D60 isn't available — see AstroEngineService
                moonChart = JsonSerializer.Deserialize<JsonElement>(chart.MoonJson),
                kp = JsonSerializer.Deserialize<JsonElement>(chart.KpJson),
                cusps = JsonSerializer.Deserialize<JsonElement>(chart.CuspJson),
            };
            return Results.Ok(response);
        }).RequireAuthorization();

        app.MapGet("/dasha", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var dasha = await db.Dashas.SingleOrDefaultAsync(d => d.UserId == principal.UserId(), ct);
            if (dasha is null)
            {
                return Results.NotFound(new { error = new { code = "NO_DASHA", message = "Save birth data first." } });
            }

            var now = DateTime.UtcNow;
            var response = new
            {
                validMonth = dasha.ValidMonth,
                maha = RefreshCurrentFlags(dasha.MahaJson, now),
                antar = RefreshCurrentFlags(dasha.AntarJson, now),
                pratyantar = RefreshCurrentFlags(dasha.PratyantarJson, now),
            };
            return Results.Ok(response);
        }).RequireAuthorization();
    }

    private record StoredPeriod(string Lord, DateTime Start, DateTime End);

    /// <summary>
    /// The `current` flag on each stored period is a snapshot computed once,
    /// when `PUT /me/birth-data` last (re)generated the Dasha — it's never
    /// updated after that, so a user who hasn't touched their birth data in
    /// a while (Pratyantar periods run just weeks; even Antar runs months)
    /// would see a stale "current" period forever. Recomputed live here from
    /// each period's own start/end instead of trusting the stored flag, so
    /// correctness doesn't depend on a scheduled job existing (there isn't
    /// one yet — see backend/README.md §Astro Engine) or on the user
    /// happening to re-save their birth data.
    /// </summary>
    private static object RefreshCurrentFlags(string periodsJson, DateTime nowUtc)
    {
        var periods = JsonSerializer.Deserialize<List<StoredPeriod>>(periodsJson, JsonConventions.CamelCase)!;
        return periods.Select(p => new
        {
            lord = p.Lord,
            start = p.Start,
            end = p.End,
            current = nowUtc >= p.Start && nowUtc < p.End,
        });
    }
}

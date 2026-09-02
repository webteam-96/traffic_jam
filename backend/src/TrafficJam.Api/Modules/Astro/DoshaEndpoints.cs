using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// `GET /doshas` — Mangal Dosha and Kaal Sarp Dosha (natal, read from the
/// already-computed/stored Chart — same data GET /chart serves, just
/// evaluated against DoshaService's rules) plus Sade Sati (transit-based,
/// evaluated fresh for "today" the same way /signal/today and
/// /transits/today do). Pitra Dosha is deliberately not computed here — its
/// definition varies enough across classical sources that picking one would
/// be presenting a judgment call as settled fact; that's left to Ask Jay.
/// </summary>
public static class DoshaEndpoints
{
    public static void MapDoshaEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/doshas", async (
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IDoshaService doshaService, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var chart = await db.Charts.SingleOrDefaultAsync(c => c.UserId == userId, ct);
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            if (chart is null || birthData is null)
            {
                return Results.NotFound(new { error = new { code = "NO_CHART", message = "Save birth data first." } });
            }

            var d1Envelope = JsonSerializer.Deserialize<JsonElement>(chart.D1Json);
            var ascendant = d1Envelope.GetProperty("ascendant");
            int? ascendantSignIndex = ascendant.GetProperty("known").GetBoolean()
                ? ascendant.GetProperty("signIndex").GetInt32()
                : null;
            var d1Planets = JsonSerializer.Deserialize<List<PlanetPosition>>(
                d1Envelope.GetProperty("planets").GetRawText(), JsonConventions.CamelCase)!;

            var natal = doshaService.ComputeNatalDoshas(d1Planets, ascendantSignIndex);

            var moonSignIndex = d1Planets.Single(p => p.Planet == "Moon").SignIndex;
            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));
            var sadeSati = doshaService.ComputeSadeSati(moonSignIndex, today);

            return Results.Ok(new { mangal = natal.Mangal, kaalSarp = natal.KaalSarp, sadeSati });
        }).RequireAuthorization();
    }
}

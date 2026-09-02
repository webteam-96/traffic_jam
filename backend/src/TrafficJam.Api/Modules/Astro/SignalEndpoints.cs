using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;
using System.Text.Json;

namespace TrafficJam.Api.Modules.Astro;

public record SignalWeights(double MoonTransit, double Panchang, double Dasha, double Transits);

public record SignalResponse(
    int Score, string Band, string Label, string Guidance, SignalBreakdown Breakdown, SignalWeights Weights);

/// <summary>
/// `GET /signal/today` per API_REQUIREMENTS.md §... "the flagship engine
/// result." Purely a synthesis endpoint — orchestrates the four already-built
/// pieces (chart's natal Moon sign, today's Panchang, today's Dasha, today's
/// transits) and hands their outputs to TrafficSignalService's pure scoring
/// function. Cached in MySQL (DailySignal), same per-user-per-day pattern as
/// Dasha, rather than Redis like transits — either is a defensible choice
/// for a "one row per user per day" cache; MySQL was picked here just to
/// keep it queryable/inspectable the same way Dasha and Charts are.
/// </summary>
public static class SignalEndpoints
{
    public static void MapSignalEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/signal/today", async (
            DateOnly? date, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IAstroEngineService astroEngine, IPanchangService panchangService, IDashaService dashaService,
            ITransitService transitService, ITrafficSignalService signalService, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            if (birthData is null)
            {
                return Results.NotFound(new { error = new { code = "NO_BIRTH_DATA", message = "Save birth data first." } });
            }

            var targetDate = date ?? DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));

            var cached = await db.DailySignals.SingleOrDefaultAsync(s => s.UserId == userId && s.Date == targetDate, ct);
            if (cached is not null)
            {
                var cachedBreakdown = JsonSerializer.Deserialize<SignalBreakdown>(cached.BreakdownJson)!;
                return Results.Ok(BuildResponse(cached.Score, cached.Band, cachedBreakdown));
            }

            var timeKnown = !birthData.UnknownTime && birthData.Tob is not null;
            var localDateTime = birthData.Dob.ToDateTime(birthData.Tob ?? new TimeOnly(12, 0));
            var tz = TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone);
            var birthUtc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified), tz);

            var natalChart = astroEngine.ComputeBirthChart(birthUtc, birthData.Lat, birthData.Lng, timeKnown);
            var natalMoonSign = natalChart.D1.Single(p => p.Planet == "Moon").SignIndex;

            var panchang = panchangService.Compute(targetDate, birthData.Lat, birthData.Lng, birthData.Timezone);
            var dasha = dashaService.Compute(birthUtc, natalMoonSign * 30.0 + natalChart.D1.Single(p => p.Planet == "Moon").DegreeInSign, DateTime.UtcNow);
            var transits = transitService.Compute(targetDate, natalLagnaSignIndex: null, natalMoonSign);

            var moonHouseFromMoon = transits.Planets.Single(p => p.Planet == "Moon").HouseFromMoon;
            var jupiterHouseFromMoon = transits.Planets.Single(p => p.Planet == "Jupiter").HouseFromMoon;
            var saturnHouseFromMoon = transits.Planets.Single(p => p.Planet == "Saturn").HouseFromMoon;
            var rahuHouseFromMoon = transits.Planets.Single(p => p.Planet == "Rahu").HouseFromMoon;
            var ketuHouseFromMoon = transits.Planets.Single(p => p.Planet == "Ketu").HouseFromMoon;

            var result = signalService.Score(
                moonHouseFromMoon,
                panchang.TithiIndex, panchang.YogaIndex, panchang.KaranaName,
                dasha.CurrentMaha.Lord, dasha.CurrentAntar.Lord,
                jupiterHouseFromMoon, saturnHouseFromMoon, rahuHouseFromMoon, ketuHouseFromMoon);

            var candidate = new DailySignal
            {
                UserId = userId, Date = targetDate, Score = result.Score, Band = result.Band,
                BreakdownJson = JsonSerializer.Serialize(result.Breakdown),
            };
            db.DailySignals.Add(candidate);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // Another concurrent request for this (user, date) already
                // cached it first — e.g. the Home screen's Vibe Meter card and
                // several detail screens all requesting "today" on first load.
                // Our own computed result is just as valid; no need to re-read.
            }

            return Results.Ok(BuildResponse(result.Score, result.Band, result.Breakdown));
        }).RequireAuthorization();
    }

    private static SignalResponse BuildResponse(int score, string band, SignalBreakdown breakdown)
    {
        var (label, guidance) = TrafficSignalService.LabelAndGuidance(band);
        return new SignalResponse(score, band, label, guidance, breakdown, new SignalWeights(0.30, 0.25, 0.25, 0.20));
    }
}

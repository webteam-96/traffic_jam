using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Astro;

public record ComputeChartRequest(DateOnly Dob, TimeOnly? Tob, bool UnknownTime, double Lat, double Lng, string Timezone);

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

        // Stateless chart+Dasha computation for a birth date/time/place that
        // isn't the signed-in user's own — "Get Kundli" for family/friends
        // (BACKEND_REQUIREMENTS.md §5.3). Nothing is persisted: no
        // BirthData/Chart/Dasha row is written, so this can't collide with
        // (or overwrite) the user's own saved birth data. Returns the same
        // `chart`/`dasha` field shapes as GET /chart and GET /dasha so the
        // frontend can reuse identical parsing/rendering code for both.
        app.MapPost("/chart/compute", (
            ComputeChartRequest request, IAstroEngineService astroEngine, IKpService kpService,
            IDashaService dashaService, IDoshaService doshaService) =>
        {
            var timeKnown = !request.UnknownTime && request.Tob is not null;
            var localDateTime = request.Dob.ToDateTime(request.Tob ?? new TimeOnly(12, 0));
            var tz = TimeZoneInfo.FindSystemTimeZoneById(request.Timezone);
            var birthUtc = TimeZoneInfo.ConvertTimeToUtc(
                DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified), tz);

            var result = astroEngine.ComputeBirthChart(birthUtc, request.Lat, request.Lng, timeKnown);

            object kpJson = Array.Empty<object>();
            object cuspJson = Array.Empty<object>();
            if (timeKnown)
            {
                var kpChart = kpService.Compute(new CosineKitty.AstroTime(birthUtc), request.Lat, request.Lng, result.D1);
                kpJson = kpChart.Planets;
                cuspJson = kpChart.Cusps;
            }

            var chartResponse = new
            {
                ayanamsa = result.AyanamsaDegrees.ToString("F4"),
                nakshatra = $"{result.MoonNakshatra.Name}-{result.MoonNakshatra.Pada}",
                computedAt = DateTime.UtcNow,
                ascendant = new
                {
                    tropicalLongitude = result.AscendantTropicalLongitude,
                    siderealLongitude = result.AscendantSiderealLongitude,
                    signIndex = result.AscendantSignIndex,
                    sign = result.AscendantSignIndex is int ascSign ? VedicMath.SignNames[ascSign] : null,
                    known = timeKnown,
                },
                d1 = result.D1,
                d9 = result.D9,
                d10 = result.D10,
                d60 = result.D60 ?? (object)Array.Empty<object>(),
                moonChart = result.MoonChart,
                kp = kpJson,
                cusps = cuspJson,
            };

            var moonPosition = result.D1.Single(p => p.Planet == "Moon");
            var moonSiderealLongitude = moonPosition.SignIndex * 30.0 + moonPosition.DegreeInSign;
            var asOfUtc = DateTime.UtcNow;
            var dashaResult = dashaService.Compute(birthUtc, moonSiderealLongitude, asOfUtc);

            var dashaResponse = new
            {
                validMonth = new DateOnly(asOfUtc.Year, asOfUtc.Month, 1),
                maha = SerializeDashaPeriods(dashaResult.MahaTimeline, dashaResult.CurrentMaha, asOfUtc),
                antar = SerializeDashaPeriods(dashaResult.CurrentAntarList, dashaResult.CurrentAntar, asOfUtc),
                pratyantar = SerializeDashaPeriods(dashaResult.CurrentPratyantarList, null, asOfUtc),
            };

            var natalDoshas = doshaService.ComputeNatalDoshas(result.D1, result.AscendantSignIndex);
            var moonSignIndex = moonPosition.SignIndex;
            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTime.UtcNow, tz));
            var sadeSati = doshaService.ComputeSadeSati(moonSignIndex, today);
            var doshaResponse = new { mangal = natalDoshas.Mangal, kaalSarp = natalDoshas.KaalSarp, sadeSati };

            return Results.Ok(new { chart = chartResponse, dasha = dashaResponse, doshas = doshaResponse });
        }).RequireAuthorization();
    }

    private static IEnumerable<object> SerializeDashaPeriods(
        IReadOnlyList<DashaPeriod> periods, DashaPeriod? current, DateTime asOfUtc) =>
        periods.Select(p => new
        {
            lord = p.Lord,
            start = p.Start,
            end = p.End,
            current = ReferenceEquals(p, current) || (asOfUtc >= p.Start && asOfUtc < p.End),
        });

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

using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Modules.Astro;

public record PanchangWindow(DateTime Start, DateTime End);
public record PanchangElement(string Name, DateTime EndsAt);

public record PanchangResponse(
    DateOnly Date, string Paksha,
    PanchangElement Tithi, PanchangElement Nakshatra, PanchangElement Yoga, PanchangElement Karana,
    PanchangWindow RahuKaal, PanchangWindow Yamaganda, PanchangWindow Gulika, PanchangWindow Abhijit,
    DateTime Sunrise, DateTime Sunset, DateTime? Moonrise, DateTime? Moonset);

/// <summary>
/// `GET /panchang/today` per API_REQUIREMENTS.md §2.2. Location comes from
/// the signed-in user's own birth place (the app has no separate "current
/// city" concept yet) — same simplification Edit Birth Data already uses.
/// Cache-fills PanchangCache per (city, date) on demand rather than needing
/// the nightly ~03:00 IST precompute batch job (BACKEND_REQUIREMENTS.md's
/// "Panchang precompute") — that cron job is a separate, not-yet-built
/// follow-up for pre-warming the cache before users wake up; without it,
/// the first request of the day for a given city just computes it live
/// instead of reading an already-warm cache, which is correct, just not
/// pre-warmed.
/// </summary>
public static class PanchangEndpoints
{
    public static void MapPanchangEndpoints(this WebApplication app)
    {
        app.MapGet("/panchang/today", async (
            DateOnly? date, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IPanchangService panchangService, CancellationToken ct) =>
        {
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == principal.UserId(), ct);
            if (birthData is null)
            {
                return Results.NotFound(new { error = new { code = "NO_BIRTH_DATA", message = "Save birth data first." } });
            }

            var targetDate = date ?? DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone)));

            var cached = await db.PanchangCache
                .SingleOrDefaultAsync(p => p.City == birthData.Place && p.Date == targetDate, ct);

            if (cached is null)
            {
                var result = panchangService.Compute(targetDate, birthData.Lat, birthData.Lng, birthData.Timezone);
                cached = new PanchangCache
                {
                    City = birthData.Place, Date = targetDate,
                    Paksha = result.Paksha,
                    Tithi = result.TithiName, TithiEndsAt = result.TithiEndsAt,
                    Nakshatra = result.NakshatraName, NakshatraEndsAt = result.NakshatraEndsAt,
                    Yoga = result.YogaName, YogaEndsAt = result.YogaEndsAt,
                    Karana = result.KaranaName, KaranaEndsAt = result.KaranaEndsAt,
                    RahuKaalStart = result.RahuKaalStart, RahuKaalEnd = result.RahuKaalEnd,
                    YamagandaKaalStart = result.YamagandaStart, YamagandaKaalEnd = result.YamagandaEnd,
                    GulikaKaalStart = result.GulikaStart, GulikaKaalEnd = result.GulikaEnd,
                    AbhijitStart = result.AbhijitStart, AbhijitEnd = result.AbhijitEnd,
                    Sunrise = result.Sunrise, Sunset = result.Sunset,
                    Moonrise = result.Moonrise, Moonset = result.Moonset,
                };
                db.PanchangCache.Add(cached);
                await db.SaveChangesAsync(ct);
            }

            return Results.Ok(new PanchangResponse(
                targetDate, cached.Paksha,
                new PanchangElement(cached.Tithi, cached.TithiEndsAt),
                new PanchangElement(cached.Nakshatra, cached.NakshatraEndsAt),
                new PanchangElement(cached.Yoga, cached.YogaEndsAt),
                new PanchangElement(cached.Karana, cached.KaranaEndsAt),
                new PanchangWindow(cached.RahuKaalStart, cached.RahuKaalEnd),
                new PanchangWindow(cached.YamagandaKaalStart, cached.YamagandaKaalEnd),
                new PanchangWindow(cached.GulikaKaalStart, cached.GulikaKaalEnd),
                new PanchangWindow(cached.AbhijitStart, cached.AbhijitEnd),
                cached.Sunrise, cached.Sunset, cached.Moonrise, cached.Moonset));
        }).RequireAuthorization();
    }
}

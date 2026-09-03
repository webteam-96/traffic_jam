using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;
using TrafficJam.Api.Modules.Astro;

namespace TrafficJam.Api.Modules.Users;

public record BirthDataResponse(
    string? Name, DateOnly Dob, TimeOnly? Tob, bool UnknownTime, string Place, double Lat, double Lng, string Timezone);

public record BirthDataRequest(
    string? Name, DateOnly Dob, TimeOnly? Tob, bool UnknownTime, string Place, double Lat, double Lng, string Timezone);

public record OnboardingDraftRequest(
    string? Name, DateOnly? Dob, TimeOnly? Tob, bool? UnknownTime, string? Place, double? Lat, double? Lng, string? Timezone);

public record NotificationPreferencesResponse(
    bool Morning, bool RahuKaal, bool Events, bool Dasha, bool Remedies, Dictionary<string, string[]> Channels);

public record NotificationPreferencesRequest(
    bool Morning, bool RahuKaal, bool Events, bool Dasha, bool Remedies, Dictionary<string, string[]> Channels);

public record DeviceRequest(string FcmToken, string Platform);

public static class UserEndpoints
{
    public static void MapUserEndpoints(this IEndpointRouteBuilder app)
    {
        var me = app.MapGroup("/me").RequireAuthorization();

        me.MapGet("/birth-data", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var record = await db.BirthData
                .Include(b => b.User)
                .SingleOrDefaultAsync(b => b.UserId == principal.UserId(), ct);

            return record is null
                ? Results.NotFound()
                : Results.Ok(new BirthDataResponse(
                    record.User.Name, record.Dob, record.Tob, record.UnknownTime,
                    record.Place, record.Lat, record.Lng, record.Timezone));
        });

        me.MapPut("/birth-data", async (
            BirthDataRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db,
            IAstroEngineService astroEngine, IDashaService dashaService, IKpService kpService,
            CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var user = await db.Users.SingleAsync(u => u.Id == userId, ct);
            user.Name = request.Name;

            var existing = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            if (existing is null)
            {
                db.BirthData.Add(new BirthData
                {
                    UserId = userId,
                    Dob = request.Dob,
                    Tob = request.Tob,
                    UnknownTime = request.UnknownTime,
                    Place = request.Place,
                    Lat = request.Lat,
                    Lng = request.Lng,
                    Timezone = request.Timezone,
                });
            }
            else
            {
                existing.Dob = request.Dob;
                existing.Tob = request.Tob;
                existing.UnknownTime = request.UnknownTime;
                existing.Place = request.Place;
                existing.Lat = request.Lat;
                existing.Lng = request.Lng;
                existing.Timezone = request.Timezone;
                existing.UpdatedAt = DateTime.UtcNow;
            }

            // Saving birth data invalidates and regenerates the stored chart
            // and Dasha (BACKEND_REQUIREMENTS.md — Edit Birth Data is "Heavy
            // (regenerate)"). The Dasha table's `ValidMonth` is also meant to
            // be refreshed by a monthly scheduled job for users who don't
            // touch their birth data — that cron job isn't built yet, so
            // today Dasha only advances when birth data is re-saved.
            await RegenerateChartAndDashaAsync(db, userId, request.Dob, request.Tob, request.UnknownTime,
                request.Lat, request.Lng, request.Timezone, astroEngine, dashaService, kpService, ct);

            // The Traffic Signal score (folds Dasha into its own breakdown)
            // is cached downstream of the natal chart in DailySignals and is
            // now wrong too — found live during end-to-end testing: editing
            // birth data left GET /signal/today silently serving a stale
            // cache computed from the OLD birth data, with no error and no
            // indication anything was wrong. Transits are computed fresh on
            // every request (no cache — see TransitEndpoints' doc comment for
            // why), so they need no invalidation here. Panchang is
            // deliberately NOT touched here — it's cached per city+date, not
            // per user, so it was never wrong in the first place.
            db.DailySignals.RemoveRange(db.DailySignals.Where(s => s.UserId == userId));

            // The onboarding draft (if any) is superseded once real birth data is saved.
            var draft = await db.OnboardingDrafts.SingleOrDefaultAsync(d => d.UserId == userId, ct);
            if (draft is not null) db.OnboardingDrafts.Remove(draft);

            await db.SaveChangesAsync(ct);
            return Results.Ok();
        });

        app.MapPatch("/onboarding/draft", async (
            OnboardingDraftRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var draft = await db.OnboardingDrafts.SingleOrDefaultAsync(d => d.UserId == userId, ct);
            if (draft is null)
            {
                draft = new OnboardingDraft { UserId = userId };
                db.OnboardingDrafts.Add(draft);
            }

            if (request.Name is not null) draft.Name = request.Name;
            if (request.Dob is not null) draft.Dob = request.Dob;
            if (request.Tob is not null) draft.Tob = request.Tob;
            if (request.UnknownTime is not null) draft.UnknownTime = request.UnknownTime.Value;
            if (request.Place is not null) draft.Place = request.Place;
            if (request.Lat is not null) draft.Lat = request.Lat;
            if (request.Lng is not null) draft.Lng = request.Lng;
            if (request.Timezone is not null) draft.Timezone = request.Timezone;
            draft.UpdatedAt = DateTime.UtcNow;

            await db.SaveChangesAsync(ct);
            return Results.Ok();
        }).RequireAuthorization();

        me.MapGet("/notification-preferences", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var prefs = await db.NotificationPrefs.SingleOrDefaultAsync(p => p.UserId == principal.UserId(), ct);
            prefs ??= new NotificationPrefs { UserId = principal.UserId() };

            return Results.Ok(new NotificationPreferencesResponse(
                prefs.Morning, prefs.RahuKaal, prefs.Events, prefs.Dasha, prefs.Remedies,
                JsonSerializer.Deserialize<Dictionary<string, string[]>>(prefs.ChannelsJson) ?? []));
        });

        me.MapPut("/notification-preferences", async (
            NotificationPreferencesRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var prefs = await db.NotificationPrefs.SingleOrDefaultAsync(p => p.UserId == userId, ct);
            if (prefs is null)
            {
                prefs = new NotificationPrefs { UserId = userId };
                db.NotificationPrefs.Add(prefs);
            }

            prefs.Morning = request.Morning;
            prefs.RahuKaal = request.RahuKaal;
            prefs.Events = request.Events;
            prefs.Dasha = request.Dasha;
            prefs.Remedies = request.Remedies;
            prefs.ChannelsJson = JsonSerializer.Serialize(request.Channels);

            // TODO(notification-service): (un)subscribe the user's devices to/from
            // the corresponding FCM topics here once push infra exists.

            await db.SaveChangesAsync(ct);
            return Results.Ok();
        });

        // "Data Crypts" (privacy screen) — download-your-data. Everything
        // that's actually stored for this user, decrypted the same way it's
        // shown elsewhere in the app (BirthData's EF value converters
        // decrypt transparently on read).
        me.MapGet("/export", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var user = await db.Users.SingleAsync(u => u.Id == userId, ct);
            var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);
            var subscription = await db.Subscriptions.SingleOrDefaultAsync(s => s.UserId == userId, ct);
            var notificationPrefs = await db.NotificationPrefs.SingleOrDefaultAsync(p => p.UserId == userId, ct);
            var questions = await db.Questions.Include(q => q.Messages)
                .Where(q => q.UserId == userId).ToListAsync(ct);
            var appointments = await db.Appointments.Where(a => a.UserId == userId).ToListAsync(ct);

            return Results.Ok(new
            {
                exportedAt = DateTime.UtcNow,
                profile = new { user.Id, user.Name, user.CreatedAt },
                birthData = birthData is null ? null : new
                {
                    birthData.Dob, birthData.Tob, birthData.UnknownTime,
                    birthData.Place, birthData.Lat, birthData.Lng, birthData.Timezone,
                },
                subscription = subscription is null ? null : new
                {
                    Tier = subscription.Tier.ToString(), Cycle = subscription.Cycle.ToString(), subscription.RenewsAt,
                },
                notificationPreferences = notificationPrefs is null ? null : new
                {
                    notificationPrefs.Morning, notificationPrefs.RahuKaal, notificationPrefs.Events,
                    notificationPrefs.Dasha, notificationPrefs.Remedies,
                },
                questions = questions.Select(q => new
                {
                    q.Id, q.Domain, q.Text, Status = q.Status.ToString(), q.CreatedAt,
                    Messages = q.Messages.Select(m => new { m.Id, Sender = m.Sender.ToString(), m.Text, m.CreatedAt }),
                }),
                appointments = appointments.Select(a => new
                {
                    a.Id, a.Area, a.Email, a.Message, a.PreferredDate, a.PreferredTime,
                    Status = a.Status.ToString(), a.CreatedAt,
                }),
            });
        });

        // Account deletion — every child row (BirthData/Chart/Dasha/
        // Questions+Messages/Subscription/NotificationPrefs/Devices/
        // RefreshTokens/Appointments/Notifications) cascades via the FK
        // configuration in AppDbContext.OnModelCreating, so removing the
        // User row is enough. Irreversible; the frontend is expected to get
        // explicit confirmation before calling this.
        me.MapDelete("", async (System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var user = await db.Users.SingleAsync(u => u.Id == principal.UserId(), ct);
            db.Users.Remove(user);
            await db.SaveChangesAsync(ct);
            return Results.Ok();
        });

        me.MapPost("/devices", async (
            DeviceRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var existing = await db.Devices
                .SingleOrDefaultAsync(d => d.UserId == userId && d.FcmToken == request.FcmToken, ct);

            if (existing is null)
            {
                db.Devices.Add(new Device { UserId = userId, FcmToken = request.FcmToken, Platform = request.Platform });
                await db.SaveChangesAsync(ct);
            }

            return Results.Ok();
        });
    }

    /// <summary>
    /// Computes the birth chart (D1/D9/D10/D60, KP/Cusp) via
    /// <see cref="IAstroEngineService"/> and <see cref="IKpService"/>, and
    /// the Vimshottari Dasha via <see cref="IDashaService"/>, and upserts
    /// all of it. D60 and KP/Cusp are stored as "[]" specifically when the
    /// birth time is unknown — see AstroEngineService's and KpService's doc
    /// comments for why those two need a genuinely exact time.
    /// </summary>
    private static async Task RegenerateChartAndDashaAsync(
        AppDbContext db, Guid userId, DateOnly dob, TimeOnly? tob, bool unknownTime,
        double lat, double lng, string timezone, IAstroEngineService astroEngine, IDashaService dashaService,
        IKpService kpService, CancellationToken ct)
    {
        var timeKnown = !unknownTime && tob is not null;
        var localDateTime = dob.ToDateTime(tob ?? new TimeOnly(12, 0));
        var tz = TimeZoneInfo.FindSystemTimeZoneById(timezone);
        var birthUtc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified), tz);

        var result = astroEngine.ComputeBirthChart(birthUtc, lat, lng, timeKnown);

        var chart = await db.Charts.SingleOrDefaultAsync(c => c.UserId == userId, ct);
        if (chart is null)
        {
            chart = new Chart
            {
                UserId = userId,
                D1Json = "", D9Json = "", D10Json = "[]", D60Json = "[]",
                MoonJson = "", KpJson = "[]", CuspJson = "[]",
                Nakshatra = "", Ayanamsa = "",
            };
            db.Charts.Add(chart);
        }

        chart.D1Json = JsonSerializer.Serialize(new
        {
            ascendant = new
            {
                tropicalLongitude = result.AscendantTropicalLongitude,
                siderealLongitude = result.AscendantSiderealLongitude,
                signIndex = result.AscendantSignIndex,
                sign = result.AscendantSignIndex is int ascSign ? VedicMath.SignNames[ascSign] : null,
                known = timeKnown,
            },
            planets = result.D1,
        }, JsonConventions.CamelCase);
        // D9/D10/D60 are each wrapped with their own Lagna (ascendantSignIndex)
        // alongside their planets, the same shape D1Json already uses —
        // that's what lets each be drawn as its own house diamond instead of
        // a flat sign list. See ChartEndpoints.cs's GET /chart, which unwraps
        // this same shape back out into sibling `d9`/`d9AscendantSignIndex`
        // response fields.
        chart.D9Json = JsonSerializer.Serialize(new
        {
            ascendantSignIndex = result.D9AscendantSignIndex,
            planets = result.D9,
        }, JsonConventions.CamelCase);
        chart.D10Json = JsonSerializer.Serialize(new
        {
            ascendantSignIndex = result.D10AscendantSignIndex,
            planets = result.D10,
        }, JsonConventions.CamelCase);
        // D60 needs a genuinely exact birth time (see AstroEngineService's doc
        // comment) — an empty `planets` array here means "not available for
        // this profile", the same not-yet-computed convention used before
        // this chart existed, not a claim that the D60 chart is empty.
        chart.D60Json = JsonSerializer.Serialize(new
        {
            ascendantSignIndex = result.D60AscendantSignIndex,
            planets = (IReadOnlyList<PlanetPosition>)(result.D60 ?? []),
        }, JsonConventions.CamelCase);
        chart.MoonJson = JsonSerializer.Serialize(result.MoonChart, JsonConventions.CamelCase);

        // KP System / Cusp Chart need Placidus house cusps, which — like
        // D60 — are only meaningful with a genuinely exact birth time (more
        // so, in fact: there is no Placidus chart at all without one).
        if (timeKnown)
        {
            var kpChart = kpService.Compute(new CosineKitty.AstroTime(birthUtc), lat, lng, result.D1);
            chart.KpJson = JsonSerializer.Serialize(kpChart.Planets, JsonConventions.CamelCase);
            chart.CuspJson = JsonSerializer.Serialize(kpChart.Cusps, JsonConventions.CamelCase);
        }
        else
        {
            chart.KpJson = "[]";
            chart.CuspJson = "[]";
        }

        chart.Nakshatra = $"{result.MoonNakshatra.Name}-{result.MoonNakshatra.Pada}";
        chart.Ayanamsa = result.AyanamsaDegrees.ToString("F4");
        chart.ComputedAt = DateTime.UtcNow;

        var moonPosition = result.D1.Single(p => p.Planet == "Moon");
        var moonSiderealLongitude = moonPosition.SignIndex * 30.0 + moonPosition.DegreeInSign;
        var asOfUtc = DateTime.UtcNow;
        var dashaResult = dashaService.Compute(birthUtc, moonSiderealLongitude, asOfUtc);

        var dasha = await db.Dashas.SingleOrDefaultAsync(d => d.UserId == userId, ct);
        if (dasha is null)
        {
            dasha = new Dasha
            {
                UserId = userId, MahaJson = "", AntarJson = "", PratyantarJson = "",
                ValidMonth = new DateOnly(asOfUtc.Year, asOfUtc.Month, 1),
            };
            db.Dashas.Add(dasha);
        }

        dasha.MahaJson = SerializeDashaPeriods(dashaResult.MahaTimeline, dashaResult.CurrentMaha, asOfUtc);
        dasha.AntarJson = SerializeDashaPeriods(dashaResult.CurrentAntarList, dashaResult.CurrentAntar, asOfUtc);
        dasha.PratyantarJson = SerializeDashaPeriods(dashaResult.CurrentPratyantarList, null, asOfUtc);
        dasha.ValidMonth = new DateOnly(asOfUtc.Year, asOfUtc.Month, 1);
    }

    private static string SerializeDashaPeriods(
        IReadOnlyList<DashaPeriod> periods, DashaPeriod? current, DateTime asOfUtc) =>
        JsonSerializer.Serialize(periods.Select(p => new
        {
            lord = p.Lord,
            start = p.Start,
            end = p.End,
            current = ReferenceEquals(p, current) || (asOfUtc >= p.Start && asOfUtc < p.End),
        }), JsonConventions.CamelCase);
}

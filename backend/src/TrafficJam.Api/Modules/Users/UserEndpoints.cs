using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

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
    public static void MapUserEndpoints(this WebApplication app)
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
            BirthDataRequest request, System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
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

            // TODO(astro-engine): once the Swiss Ephemeris integration exists, saving
            // new birth data must invalidate + regenerate the stored Chart/Dasha here
            // (BACKEND_REQUIREMENTS.md — Edit Birth Data is "Heavy (regenerate)").

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
}

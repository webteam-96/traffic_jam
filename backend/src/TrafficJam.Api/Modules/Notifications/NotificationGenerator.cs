using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Modules.Astro;

namespace TrafficJam.Api.Modules.Notifications;

public interface INotificationGenerator
{
    /// <summary>
    /// Brings a user's inbox up to date: works out which notifications should
    /// exist right now, and inserts the ones that don't. Safe to call on every
    /// read — each notification carries a key unique to its subject, so a
    /// second call the same day inserts nothing.
    /// </summary>
    Task EnsureAsync(Guid userId, CancellationToken ct);
}

/// <summary>
/// Fills the inbox.
///
/// Nothing wrote notifications before this: the entity, the endpoints, the
/// preferences screen and the filter all existed, and the table stayed empty
/// forever. This is the missing half.
///
/// Notifications are generated when the inbox is READ rather than by a
/// scheduler, because there is no scheduler yet. The trade-off is honest: a
/// user only learns about their Rahu Kaal window when they open the app, not
/// at 15 minutes' notice. Every row it writes is real and preference-checked,
/// so wiring a cron or push job later means calling EnsureAsync on a timer
/// instead of on a request — no change to what gets produced.
///
/// Every category here is gated on the user's own NotificationPrefs. A
/// category switched off produces nothing at all, rather than being generated
/// and hidden.
/// </summary>
public class NotificationGenerator(
    AppDbContext db,
    IPanchangService panchangService,
    IDashaService dashaService) : INotificationGenerator
{
    public async Task EnsureAsync(Guid userId, CancellationToken ct)
    {
        var prefs = await db.NotificationPrefs.SingleOrDefaultAsync(p => p.UserId == userId, ct)
                    ?? new NotificationPrefs { UserId = userId };

        var birthData = await db.BirthData.SingleOrDefaultAsync(b => b.UserId == userId, ct);

        // Every key already used, fetched once. Cheaper than a query per
        // candidate, and the set is small — a user accrues a handful a day.
        var existingKeys = await db.Notifications
            .Where(n => n.UserId == userId)
            .Select(n => n.Type)
            .ToListAsync(ct);
        var existing = existingKeys.ToHashSet();

        var pending = new List<Notification>();

        void Add(string key, string title, string body)
        {
            if (existing.Contains(key)) return;
            existing.Add(key);
            pending.Add(new Notification
            {
                UserId = userId,
                Type = key,
                Title = title,
                Body = body,
                Source = NotificationSource.System,
            });
        }

        if (birthData is not null)
        {
            var tz = TimeZoneInfo.FindSystemTimeZoneById(birthData.Timezone);
            var localNow = TimeZoneInfo.ConvertTime(DateTime.UtcNow, tz);
            var today = DateOnly.FromDateTime(localNow);
            var stamp = today.ToString("yyyy-MM-dd");

            PanchangResult? panchang = null;
            try
            {
                panchang = panchangService.Compute(today, birthData.Lat, birthData.Lng, birthData.Timezone);
            }
            catch
            {
                // A Panchang failure must not cost the user their chat replies
                // — the categories below are independent of it.
            }

            if (prefs.Morning && panchang is not null)
            {
                Add($"morning:{stamp}",
                    "Your day ahead",
                    $"{panchang.TithiName} tithi, {panchang.NakshatraName} nakshatra. " +
                    $"Sunrise {Local(panchang.Sunrise, tz):h:mm tt}.");
            }

            if (prefs.RahuKaal && panchang is not null)
            {
                Add($"rahukaal:{stamp}",
                    "Rahu Kaal today",
                    $"{Local(panchang.RahuKaalStart, tz):h:mm tt} to {Local(panchang.RahuKaalEnd, tz):h:mm tt}. " +
                    "Best avoided for anything you want to begin.");
            }

            if (prefs.Dasha && birthData.Tob is not null)
            {
                await AddDashaShiftAsync(userId, birthData, tz, Add, ct);
            }
        }

        if (prefs.Chat)
        {
            await AddAstrologerRepliesAsync(userId, Add, ct);
        }

        if (pending.Count == 0) return;

        db.Notifications.AddRange(pending);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Two requests raced — the home screen and the inbox both opening,
            // say. The other one wrote them; nothing to do.
        }
    }

    private static DateTime Local(DateTime utc, TimeZoneInfo tz) =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), tz);

    /// <summary>
    /// Announces the Antardasha the user is currently in, once. The key is the
    /// period itself rather than the date, so it fires when a period changes
    /// and stays quiet for the months in between.
    /// </summary>
    private async Task AddDashaShiftAsync(
        Guid userId, BirthData birthData, TimeZoneInfo tz,
        Action<string, string, string> add, CancellationToken ct)
    {
        var chart = await db.Charts.SingleOrDefaultAsync(c => c.UserId == userId, ct);
        if (chart is null) return;

        var localBirth = birthData.Dob.ToDateTime(birthData.Tob!.Value);
        var birthUtc = TimeZoneInfo.ConvertTimeToUtc(
            DateTime.SpecifyKind(localBirth, DateTimeKind.Unspecified), tz);

        var moonLongitude = MoonLongitudeFrom(chart);
        if (moonLongitude is null) return;

        var dasha = dashaService.Compute(birthUtc, moonLongitude.Value, DateTime.UtcNow);

        var maha = dasha.CurrentMaha;
        var antar = dasha.CurrentAntar;

        add($"dasha:{maha.Lord}:{antar.Lord}:{antar.Start:yyyy-MM-dd}",
            $"{antar.Lord} Antardasha has begun",
            $"You are now in {antar.Lord} Antardasha within the {maha.Lord} Mahadasha, " +
            $"running to {antar.End:dd-MM-yyyy}.");
    }

    private static double? MoonLongitudeFrom(Chart chart)
    {
        try
        {
            var d1 = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(chart.D1Json);
            foreach (var planet in d1.GetProperty("planets").EnumerateArray())
            {
                if (planet.GetProperty("planet").GetString() != "Moon") continue;
                return planet.GetProperty("signIndex").GetInt32() * 30.0
                       + planet.GetProperty("degreeInSign").GetDouble();
            }
        }
        catch
        {
            // Older stored chart shape — skip the Dasha notification rather
            // than fail the whole inbox.
        }

        return null;
    }

    /// <summary>
    /// One notification per astrologer reply, keyed on the message id so a
    /// long conversation produces one per answer and never repeats.
    /// </summary>
    private async Task AddAstrologerRepliesAsync(
        Guid userId, Action<string, string, string> add, CancellationToken ct)
    {
        var replies = await db.Messages
            .Where(m => m.Sender == MessageSender.Astrologer
                        && db.Questions.Any(q => q.Id == m.QuestionId && q.UserId == userId))
            .OrderByDescending(m => m.CreatedAt)
            .Take(20)
            .Select(m => new { m.Id, m.Text, m.QuestionId })
            .ToListAsync(ct);

        foreach (var reply in replies)
        {
            var preview = reply.Text.Length > 120 ? reply.Text[..117] + "..." : reply.Text;

            // The question id rides in the key so tapping the notification can
            // open that conversation. Still unique per message, so dedupe is
            // unaffected — the key just carries its destination now.
            add($"chat:{reply.QuestionId}:{reply.Id}", "Jay has replied", preview);
        }
    }
}

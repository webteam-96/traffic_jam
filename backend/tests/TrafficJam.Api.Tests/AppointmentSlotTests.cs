using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Modules.Admin;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Consultation;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

/// <summary>
/// Published availability, booking, and the one thing that must never happen:
/// two people holding the same slot.
/// </summary>
public class AppointmentSlotTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public AppointmentSlotTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<HttpClient> AppClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session",
            new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    private async Task<HttpClient> AdminClientAsync()
    {
        var client = _factory.CreateClient();
        var login = await client.PostAsJsonAsync("/admin/auth/login",
            new AdminLoginRequest("admin@trafficjam.life", "TrafficJam2026!"));
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var tokens = await login.Content.ReadFromJsonAsync<AdminLoginResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    private static DateTime FutureSlot(int hoursAhead) =>
        DateTime.UtcNow.AddHours(hoursAhead).Date.AddHours(DateTime.UtcNow.AddHours(hoursAhead).Hour);

    private async Task<Guid> PublishSlotAsync(HttpClient admin, DateTime startsAt)
    {
        var response = await admin.PostAsJsonAsync("/admin/appointment-slots",
            new CreateSlotsRequest([startsAt]));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return (await db.AppointmentSlots.AsNoTracking()
            .SingleAsync(s => s.StartsAt == startsAt)).Id;
    }

    private static BookAppointmentRequest Booking(Guid? slotId, DateTime when) =>
        new("Career", "user@example.com", null,
            DateOnly.FromDateTime(when), TimeOnly.FromDateTime(when), slotId, "Asia/Kolkata");

    // Users only see what the astrologer published. Asserted per-slot rather
    // than on an empty list: ResetDatabaseAsync creates the schema once for
    // the class, so rows from sibling tests are still around.
    [Fact]
    public async Task Slots_AreOnlyWhatTheAdminHasPublished()
    {
        var user = await AppClientAsync("uid-slot-1");
        var when = FutureSlot(24);

        Assert.DoesNotContain(
            await user.GetFromJsonAsync<List<AppointmentSlotResponse>>("/consult/appointments/slots") ?? [],
            s => s.StartsAt == when);

        var admin = await AdminClientAsync();
        await PublishSlotAsync(admin, when);

        Assert.Contains(
            await user.GetFromJsonAsync<List<AppointmentSlotResponse>>("/consult/appointments/slots") ?? [],
            s => s.StartsAt == when);
    }

    // The headline requirement: a taken slot disappears for everyone else.
    [Fact]
    public async Task ABookedSlot_IsNoLongerOfferedToAnyone()
    {
        var admin = await AdminClientAsync();
        var first = await AppClientAsync("uid-slot-2");
        var second = await AppClientAsync("uid-slot-3");

        var when = FutureSlot(25);
        var slotId = await PublishSlotAsync(admin, when);

        Assert.Contains(
            await second.GetFromJsonAsync<List<AppointmentSlotResponse>>("/consult/appointments/slots") ?? [],
            s => s.Id == slotId);

        var booked = await first.PostAsJsonAsync("/consult/appointments", Booking(slotId, when));
        Assert.Equal(HttpStatusCode.OK, booked.StatusCode);

        // Gone for the other user, and for the one who booked it.
        Assert.DoesNotContain(
            await second.GetFromJsonAsync<List<AppointmentSlotResponse>>("/consult/appointments/slots") ?? [],
            s => s.Id == slotId);
        Assert.DoesNotContain(
            await first.GetFromJsonAsync<List<AppointmentSlotResponse>>("/consult/appointments/slots") ?? [],
            s => s.Id == slotId);
    }

    // And if someone tries anyway — a stale screen, a replayed request — the
    // second booking is refused rather than silently overwriting the first.
    [Fact]
    public async Task BookingAnAlreadyTakenSlot_IsRefused()
    {
        var admin = await AdminClientAsync();
        var first = await AppClientAsync("uid-slot-4");
        var second = await AppClientAsync("uid-slot-5");

        var when = FutureSlot(26);
        var slotId = await PublishSlotAsync(admin, when);

        await first.PostAsJsonAsync("/consult/appointments", Booking(slotId, when));
        var clash = await second.PostAsJsonAsync("/consult/appointments", Booking(slotId, when));

        Assert.Equal(HttpStatusCode.Conflict, clash.StatusCode);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.Appointments.CountAsync(a => a.SlotId == slotId));
    }

    // Booking a published slot needs no further agreement — the astrologer
    // published that hour.
    [Fact]
    public async Task BookingASlot_IsConfirmedImmediately()
    {
        var admin = await AdminClientAsync();
        var user = await AppClientAsync("uid-slot-6");
        var when = FutureSlot(27);
        var slotId = await PublishSlotAsync(admin, when);

        var response = await user.PostAsJsonAsync("/consult/appointments", Booking(slotId, when));
        var body = await response.Content.ReadFromJsonAsync<BookAppointmentResponse>();

        Assert.Equal("Confirmed", body!.Status);
    }

    // Asking for your own time is a request, not a booking — it only becomes
    // real when the astrologer agrees.
    [Fact]
    public async Task AManualTimeRequest_StaysPendingUntilTheAstrologerConfirms()
    {
        var user = await AppClientAsync("uid-slot-7");
        var when = FutureSlot(28);

        var response = await user.PostAsJsonAsync("/consult/appointments", Booking(null, when));
        var body = await response.Content.ReadFromJsonAsync<BookAppointmentResponse>();
        Assert.Equal("Pending", body!.Status);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var appointment = await db.Appointments.AsNoTracking().SingleAsync(a => a.Id == body.AppointmentId);
            Assert.Null(appointment.ScheduledAt);   // not yet a real time
            Assert.Null(appointment.SlotId);
        }

        var admin = await AdminClientAsync();
        await admin.PatchAsJsonAsync($"/admin/appointments/{body.AppointmentId}/status",
            new AdminUpdateAppointmentStatusRequest("Confirmed"));

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var appointment = await db.Appointments.AsNoTracking().SingleAsync(a => a.Id == body.AppointmentId);
            Assert.NotNull(appointment.ScheduledAt);
        }
    }

    // Cancelling has to give the hour back, or one cancellation removes it
    // from circulation forever.
    [Fact]
    public async Task CancellingABooking_ReturnsTheSlotToThePool()
    {
        var admin = await AdminClientAsync();
        var user = await AppClientAsync("uid-slot-8");
        var when = FutureSlot(29);
        var slotId = await PublishSlotAsync(admin, when);

        var booked = await user.PostAsJsonAsync("/consult/appointments", Booking(slotId, when));
        var body = await booked.Content.ReadFromJsonAsync<BookAppointmentResponse>();

        await admin.PatchAsJsonAsync($"/admin/appointments/{body!.AppointmentId}/status",
            new AdminUpdateAppointmentStatusRequest("Cancelled"));

        Assert.Contains(
            await user.GetFromJsonAsync<List<AppointmentSlotResponse>>("/consult/appointments/slots") ?? [],
            s => s.Id == slotId);
    }

    // An hour that has already gone is not availability.
    [Fact]
    public async Task PastSlots_AreNeverOffered()
    {
        var user = await AppClientAsync("uid-slot-9");
        Guid pastSlotId;

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var slot = new AppointmentSlot { StartsAt = DateTime.UtcNow.AddHours(-2) };
            db.AppointmentSlots.Add(slot);
            await db.SaveChangesAsync();
            pastSlotId = slot.Id;
        }

        Assert.DoesNotContain(
            await user.GetFromJsonAsync<List<AppointmentSlotResponse>>("/consult/appointments/slots") ?? [],
            s => s.Id == pastSlotId);
    }

    [Fact]
    public async Task PublishingTheSameTimeTwice_DoesNotDuplicateIt()
    {
        var admin = await AdminClientAsync();
        var when = FutureSlot(30);

        await admin.PostAsJsonAsync("/admin/appointment-slots", new CreateSlotsRequest([when]));
        var again = await admin.PostAsJsonAsync("/admin/appointment-slots", new CreateSlotsRequest([when]));
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.AppointmentSlots.CountAsync(s => s.StartsAt == when));
    }

    // Deleting a booked slot would strand a real appointment.
    [Fact]
    public async Task ABookedSlot_CannotBeDeleted()
    {
        var admin = await AdminClientAsync();
        var user = await AppClientAsync("uid-slot-10");
        var when = FutureSlot(31);
        var slotId = await PublishSlotAsync(admin, when);

        await user.PostAsJsonAsync("/consult/appointments", Booking(slotId, when));
        var deleted = await admin.DeleteAsync($"/admin/appointment-slots/{slotId}");

        Assert.Equal(HttpStatusCode.Conflict, deleted.StatusCode);
    }

    [Fact]
    public async Task AFreeSlot_CanBeDeleted()
    {
        var admin = await AdminClientAsync();
        var slotId = await PublishSlotAsync(admin, FutureSlot(32));

        var deleted = await admin.DeleteAsync($"/admin/appointment-slots/{slotId}");

        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
    }

    [Fact]
    public async Task PublishingATimeInThePast_IsRejected()
    {
        var admin = await AdminClientAsync();

        var response = await admin.PostAsJsonAsync("/admin/appointment-slots",
            new CreateSlotsRequest([DateTime.UtcNow.AddHours(-1)]));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task SlotEndpoints_RejectANonAdminToken()
    {
        var user = await AppClientAsync("uid-slot-11");

        var response = await user.PostAsJsonAsync("/admin/appointment-slots",
            new CreateSlotsRequest([FutureSlot(33)]));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}

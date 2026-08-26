using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Notifications;
using Xunit;

namespace TrafficJam.Api.Tests;

public class NotificationEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public NotificationEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<(HttpClient client, Guid userId)> AuthedClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session",
            new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);

        var me = await client.GetFromJsonAsync<MeResponse>("/me");
        return (client, me!.Id);
    }

    // Notifications are created by the backend's own batch jobs, not a user-facing
    // endpoint — seeding directly via the DbContext mirrors that.
    private async Task SeedAsync(Guid userId, string title, bool read, TrafficJam.Api.Data.Entities.NotificationSource source)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Notifications.Add(new TrafficJam.Api.Data.Entities.Notification
        {
            UserId = userId, Type = "test", Title = title, Body = "body", Read = read, Source = source,
        });
        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task Get_ReturnsOnlyTheCallingUsersNotifications()
    {
        var (client, userId) = await AuthedClientAsync("uid-notif-list-1");
        var (_, otherUserId) = await AuthedClientAsync("uid-notif-list-2");
        await SeedAsync(userId, "Mine", read: false, TrafficJam.Api.Data.Entities.NotificationSource.System);
        await SeedAsync(otherUserId, "Not mine", read: false, TrafficJam.Api.Data.Entities.NotificationSource.System);

        var results = await client.GetFromJsonAsync<List<NotificationResponse>>("/notifications");

        Assert.Single(results!);
        Assert.Equal("Mine", results![0].Title);
    }

    [Fact]
    public async Task Get_WithUnreadFilter_ExcludesReadOnes()
    {
        var (client, userId) = await AuthedClientAsync("uid-notif-unread-1");
        await SeedAsync(userId, "Read one", read: true, TrafficJam.Api.Data.Entities.NotificationSource.System);
        await SeedAsync(userId, "Unread one", read: false, TrafficJam.Api.Data.Entities.NotificationSource.Team);

        var results = await client.GetFromJsonAsync<List<NotificationResponse>>("/notifications?unread=true");

        Assert.Single(results!);
        Assert.Equal("Unread one", results![0].Title);
        Assert.Equal("team", results[0].Source);
    }

    [Fact]
    public async Task MarkRead_ThenGetUnread_NoLongerIncludesIt()
    {
        var (client, userId) = await AuthedClientAsync("uid-notif-read-1");
        await SeedAsync(userId, "Will be read", read: false, TrafficJam.Api.Data.Entities.NotificationSource.System);
        var list = await client.GetFromJsonAsync<List<NotificationResponse>>("/notifications");

        var markResponse = await client.PostAsync($"/notifications/{list![0].Id}/read", null);
        Assert.Equal(HttpStatusCode.OK, markResponse.StatusCode);

        var afterUnread = await client.GetFromJsonAsync<List<NotificationResponse>>("/notifications?unread=true");
        Assert.Empty(afterUnread!);
    }

    [Fact]
    public async Task MarkRead_ForAnotherUsersNotification_Returns404()
    {
        var (_, ownerId) = await AuthedClientAsync("uid-notif-owner");
        await SeedAsync(ownerId, "Owner's notification", read: false, TrafficJam.Api.Data.Entities.NotificationSource.System);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notifId = db.Notifications.First(n => n.UserId == ownerId).Id;

        var (attackerClient, _) = await AuthedClientAsync("uid-notif-attacker");
        var response = await attackerClient.PostAsync($"/notifications/{notifId}/read", null);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task ReadAll_MarksEveryUnreadNotificationForThatUser()
    {
        var (client, userId) = await AuthedClientAsync("uid-notif-readall");
        await SeedAsync(userId, "One", read: false, TrafficJam.Api.Data.Entities.NotificationSource.System);
        await SeedAsync(userId, "Two", read: false, TrafficJam.Api.Data.Entities.NotificationSource.Team);

        var response = await client.PostAsync("/notifications/read-all", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var afterUnread = await client.GetFromJsonAsync<List<NotificationResponse>>("/notifications?unread=true");
        Assert.Empty(afterUnread!);
    }
}

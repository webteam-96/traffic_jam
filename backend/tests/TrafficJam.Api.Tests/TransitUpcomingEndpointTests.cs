using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class TransitUpcomingEndpointTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public TransitUpcomingEndpointTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<HttpClient> AuthedClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session", new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    private async Task GrantSagaPlusAsync(string uid)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var userId = await db.Users.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        db.Subscriptions.Add(new Subscription { UserId = userId, Tier = SubscriptionTier.SagaPlus, RenewsAt = DateTime.UtcNow.AddDays(30) });
        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task GetUpcoming_WithoutBirthData_Returns404()
    {
        var client = await AuthedClientAsync("uid-upcoming-nodata");
        var response = await client.GetAsync("/transits/upcoming");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetUpcoming_FreeTier_OnlyReturnsNonDeepSpacePlanets()
    {
        var client = await AuthedClientAsync("uid-upcoming-1");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Upcoming Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var events = await client.GetFromJsonAsync<JsonElement>("/transits/upcoming");

        // Free tier: Jupiter/Saturn/Rahu/Ketu ("deep-space transits") are a
        // Saga+ perk — only Sun and Mars come through.
        Assert.Equal(2, events.GetArrayLength());
        var planets = events.EnumerateArray().Select(e => e.GetProperty("planet").GetString()).ToList();
        Assert.Equal(new[] { "Sun", "Mars" }.OrderBy(p => p), planets.OrderBy(p => p));

        var dates = events.EnumerateArray().Select(e => DateOnly.Parse(e.GetProperty("date").GetString()!)).ToList();
        Assert.Equal(dates.OrderBy(d => d), dates); // sorted soonest-first

        var first = events.EnumerateArray().First();
        Assert.NotEqual(first.GetProperty("fromSign").GetString(), first.GetProperty("toSign").GetString());
    }

    [Fact]
    public async Task GetUpcoming_SagaPlus_ReturnsOneIngressPerWatchedPlanetSortedByDate()
    {
        var client = await AuthedClientAsync("uid-upcoming-sagaplus");
        await GrantSagaPlusAsync("uid-upcoming-sagaplus");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Upcoming Saga+ Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var events = await client.GetFromJsonAsync<JsonElement>("/transits/upcoming");

        Assert.Equal(6, events.GetArrayLength()); // Sun, Mars, Jupiter, Saturn, Rahu, Ketu
        var planets = events.EnumerateArray().Select(e => e.GetProperty("planet").GetString()).ToList();
        Assert.Equal(planets.Distinct().Count(), planets.Count); // one event per planet
        Assert.Equal(new[] { "Sun", "Mars", "Jupiter", "Saturn", "Rahu", "Ketu" }.OrderBy(p => p),
            planets.OrderBy(p => p));
    }

    [Fact]
    public async Task GetUpcoming_WithoutAuth_Returns401()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/transits/upcoming");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}

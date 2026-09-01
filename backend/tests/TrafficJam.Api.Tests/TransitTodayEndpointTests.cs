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

// "Deep-space transits" gating on /transits/today — Saga+ Monthly/Annual's
// documented feature (BACKEND_REQUIREMENTS.md "Tier gates premium features
// across the app"). Free tier still sees the fast/personal planets (Sun,
// Moon, Mars, Mercury, Venus); the slow outer grahas (Jupiter, Saturn, Rahu,
// Ketu — GrahaPositions.MajorTransitPlanets) are Saga+ only.
public class TransitTodayEndpointTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public TransitTodayEndpointTests(TrafficJamApiFactory factory) => _factory = factory;

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
    public async Task GetToday_FreeTier_OmitsDeepSpacePlanets()
    {
        var client = await AuthedClientAsync("uid-today-free");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Today Free Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var result = await client.GetFromJsonAsync<JsonElement>("/transits/today");

        var planets = result.GetProperty("planets").EnumerateArray()
            .Select(p => p.GetProperty("planet").GetString()).ToList();
        Assert.DoesNotContain("Jupiter", planets);
        Assert.DoesNotContain("Saturn", planets);
        Assert.DoesNotContain("Rahu", planets);
        Assert.DoesNotContain("Ketu", planets);
        Assert.Contains("Sun", planets);
        Assert.Contains("Moon", planets);
    }

    [Fact]
    public async Task GetToday_SagaPlus_IncludesDeepSpacePlanets()
    {
        var client = await AuthedClientAsync("uid-today-sagaplus");
        await GrantSagaPlusAsync("uid-today-sagaplus");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Today Saga+ Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var result = await client.GetFromJsonAsync<JsonElement>("/transits/today");

        var planets = result.GetProperty("planets").EnumerateArray()
            .Select(p => p.GetProperty("planet").GetString()).ToList();
        Assert.Contains("Jupiter", planets);
        Assert.Contains("Saturn", planets);
        Assert.Contains("Rahu", planets);
        Assert.Contains("Ketu", planets);
    }

    // Regression guard for the Redis-cache path added alongside gating: the
    // cache stores the full unfiltered result once, and the tier filter is
    // re-applied on every request on the way out — including a cache *hit*,
    // which deserializes the cached JSON back into a TransitResult before
    // filtering rather than returning the cached bytes untouched. Requesting
    // twice proves the second (cache-hit) response is filtered too, not just
    // the first (compute-fresh) one.
    [Fact]
    public async Task GetToday_SagaPlus_CacheHitStillIncludesDeepSpacePlanets()
    {
        var client = await AuthedClientAsync("uid-today-cachehit-saga");
        await GrantSagaPlusAsync("uid-today-cachehit-saga");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Cache Hit Saga+", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        await client.GetFromJsonAsync<JsonElement>("/transits/today"); // warms the cache
        var second = await client.GetFromJsonAsync<JsonElement>("/transits/today"); // cache hit

        var planets = second.GetProperty("planets").EnumerateArray()
            .Select(p => p.GetProperty("planet").GetString()).ToList();
        Assert.Contains("Jupiter", planets);
        Assert.Contains("Saturn", planets);
    }
}

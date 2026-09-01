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

public class PanchangEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public PanchangEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

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
    public async Task GetToday_WithoutBirthData_Returns404()
    {
        var client = await AuthedClientAsync("uid-panchang-nodata");
        var response = await client.GetAsync("/panchang/today");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetToday_WithBirthDataSaved_ReturnsRealPanchang()
    {
        var client = await AuthedClientAsync("uid-panchang-1");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Panchang Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var panchang = await client.GetFromJsonAsync<JsonElement>("/panchang/today");

        Assert.False(string.IsNullOrWhiteSpace(panchang.GetProperty("tithi").GetProperty("name").GetString()));
        Assert.True(panchang.TryGetProperty("rahuKaal", out _));
        Assert.True(panchang.TryGetProperty("abhijit", out _));
    }

    // Regression test: two requests for the same (city, date) that both miss
    // the cache used to race on the INSERT — the loser crashed the request
    // with a 500 (MySqlException: Duplicate entry for PanchangCache.PRIMARY)
    // instead of just reading what the winner wrote. This is exactly what
    // happens in the app when the Home screen's Panchang card and Vibe
    // Meter card both request "today" concurrently on first load — see
    // PanchangEndpoints.cs's catch(DbUpdateException).
    [Fact]
    public async Task GetToday_TwoConcurrentRequestsForSameUncachedDay_BothSucceedWithMatchingData()
    {
        var client = await AuthedClientAsync("uid-panchang-race");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Race Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var responses = await Task.WhenAll(
            client.GetAsync("/panchang/today"),
            client.GetAsync("/panchang/today"),
            client.GetAsync("/panchang/today"));

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));

        var bodies = await Task.WhenAll(responses.Select(r => r.Content.ReadFromJsonAsync<JsonElement>()));
        var tithiNames = bodies.Select(b => b.GetProperty("tithi").GetProperty("name").GetString()).Distinct();
        Assert.Single(tithiNames); // every response reflects the same cached row
    }

    // "Basic Panchang" (Free) vs "Unlimited Panchang" (Saga+) —
    // BACKEND_REQUIREMENTS.md's documented Saga+ feature. Today is always
    // free; any other date is the paywalled part.
    [Fact]
    public async Task GetToday_WithoutDate_IsFreeRegardlessOfTier()
    {
        var client = await AuthedClientAsync("uid-panchang-free-today");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Free Today Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var response = await client.GetAsync("/panchang/today");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetToday_WithOtherDate_FreeTier_Returns402()
    {
        var client = await AuthedClientAsync("uid-panchang-free-otherdate");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Free Other Date Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var response = await client.GetAsync("/panchang/today?date=2026-12-25");

        Assert.Equal(HttpStatusCode.PaymentRequired, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("SAGA_PLUS_REQUIRED", body.GetProperty("error").GetProperty("code").GetString());
    }

    [Fact]
    public async Task GetToday_WithOtherDate_SagaPlus_ReturnsRealPanchang()
    {
        var client = await AuthedClientAsync("uid-panchang-saga-otherdate");
        await GrantSagaPlusAsync("uid-panchang-saga-otherdate");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Saga+ Other Date Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var response = await client.GetAsync("/panchang/today?date=2026-12-25");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var panchang = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("2026-12-25", panchang.GetProperty("date").GetString());
    }
}

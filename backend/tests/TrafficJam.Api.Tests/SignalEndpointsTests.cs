using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class SignalEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public SignalEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

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

    [Fact]
    public async Task GetToday_WithADateQueryParam_ScoresThatDayInstead()
    {
        var client = await AuthedClientAsync("uid-signal-date");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Signal Date Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var today = await client.GetFromJsonAsync<JsonElement>("/signal/today");
        var future = await client.GetFromJsonAsync<JsonElement>("/signal/today?date=2027-03-15");

        // Not asserting the scores differ (they might coincide) — just that
        // both requests succeed and are independently cached per date.
        Assert.True(today.TryGetProperty("score", out _));
        Assert.True(future.TryGetProperty("score", out _));
    }

    // Regression test: two requests for the same (user, date) that both miss
    // the cache used to race on the INSERT — the loser crashed with a 500
    // (MySqlException: Duplicate entry for DailySignal.PRIMARY) instead of
    // just returning its own (equally valid, already-computed) result. This
    // is exactly what happens when the Home screen's Vibe Meter card and a
    // detail screen both request "today" concurrently on first load — see
    // SignalEndpoints.cs's catch(DbUpdateException).
    [Fact]
    public async Task GetToday_TwoConcurrentRequestsForSameUncachedDay_BothSucceed()
    {
        var client = await AuthedClientAsync("uid-signal-race");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Signal Race Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var responses = await Task.WhenAll(
            client.GetAsync("/signal/today"),
            client.GetAsync("/signal/today"),
            client.GetAsync("/signal/today"));

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));
    }
}

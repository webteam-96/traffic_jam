using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Modules.Astro;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

/// <summary>
/// A chart is computed once and stored, so an engine improvement reaches
/// nobody who already has one unless something refreshes it. These cover that
/// refresh — the thing that was missing when the KP ayanamsa fix and the outer
/// planets shipped to new users only.
/// </summary>
public class ChartEngineVersionTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public ChartEngineVersionTests(TrafficJamApiFactory factory) => _factory = factory;

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

    private static async Task SaveBirthDataAsync(HttpClient client) =>
        await client.PutAsJsonAsync("/me/birth-data", new
        {
            name = "Test", dob = "1988-10-24", tob = "10:12:00", unknownTime = false,
            place = "Mumbai, Maharashtra, India", lat = 19.0760, lng = 72.8777,
            timezone = "Asia/Kolkata",
        });

    /// <summary>Rewinds a stored chart to look like one an older engine wrote.</summary>
    private async Task MakeStaleAsync(Guid userId)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var chart = await db.Charts.SingleAsync(c => c.UserId == userId);
        chart.EngineVersion = 0;
        // Nine grahas and no KP Ascendant row, as version 0 produced.
        chart.KpJson = "[]";
        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task AFreshlySavedChart_IsStampedWithTheCurrentVersion()
    {
        var (client, userId) = await AuthedClientAsync("uid-ver-1");
        await SaveBirthDataAsync(client);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var chart = await db.Charts.AsNoTracking().SingleAsync(c => c.UserId == userId);

        Assert.Equal(AstroEngineVersion.Current, chart.EngineVersion);
    }

    // The headline behaviour: an old chart is brought up to date on read,
    // without the user doing anything.
    [Fact]
    public async Task AStaleChart_IsRecomputedWhenRead()
    {
        var (client, userId) = await AuthedClientAsync("uid-ver-2");
        await SaveBirthDataAsync(client);
        await MakeStaleAsync(userId);

        var chart = await client.GetFromJsonAsync<JsonElement>("/chart");

        // The KP data version 0 never had is there.
        Assert.NotEqual(0, chart.GetProperty("kp").GetArrayLength());

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var stored = await db.Charts.AsNoTracking().SingleAsync(c => c.UserId == userId);
        Assert.Equal(AstroEngineVersion.Current, stored.EngineVersion);
    }

    // The specific thing that prompted this: outer planets missing from charts
    // computed before they were added.
    [Fact]
    public async Task AStaleChart_GainsUranusNeptuneAndPluto()
    {
        var (client, userId) = await AuthedClientAsync("uid-ver-3");
        await SaveBirthDataAsync(client);
        await MakeStaleAsync(userId);

        var chart = await client.GetFromJsonAsync<JsonElement>("/chart");
        var names = chart.GetProperty("d1").EnumerateArray()
            .Select(p => p.GetProperty("planet").GetString())
            .ToList();

        Assert.Contains("Uranus", names);
        Assert.Contains("Neptune", names);
        Assert.Contains("Pluto", names);
    }

    // Recomputing on every read would be wasteful and would churn the row;
    // it must happen once and then stop.
    [Fact]
    public async Task AnUpToDateChart_IsNotRecomputed()
    {
        var (client, userId) = await AuthedClientAsync("uid-ver-4");
        await SaveBirthDataAsync(client);

        DateTime firstComputedAt;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            firstComputedAt = (await db.Charts.AsNoTracking().SingleAsync(c => c.UserId == userId)).ComputedAt;
        }

        await client.GetAsync("/chart");
        await client.GetAsync("/chart");

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var stored = await db.Charts.AsNoTracking().SingleAsync(c => c.UserId == userId);
            Assert.Equal(firstComputedAt, stored.ComputedAt);
        }
    }
}

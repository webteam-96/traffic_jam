using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class ChartEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public ChartEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

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
    public async Task GetChart_BeforeBirthDataSaved_Returns404()
    {
        var client = await AuthedClientAsync("uid-chart-1");
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/chart")).StatusCode);
    }

    [Fact]
    public async Task GetDasha_BeforeBirthDataSaved_Returns404()
    {
        var client = await AuthedClientAsync("uid-chart-2");
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/dasha")).StatusCode);
    }

    [Fact]
    public async Task GetChart_AfterBirthDataSaved_ReturnsFullyPopulatedCamelCaseChart()
    {
        var client = await AuthedClientAsync("uid-chart-3");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Chart Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var response = await client.GetAsync("/chart");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var chart = await response.Content.ReadFromJsonAsync<JsonElement>();

        // Every level of this response — the endpoint's own wrapper fields
        // AND the nested planet/cusp objects pulled from the stored chart
        // JSON — must be camelCase. This is exactly the mixed-casing bug
        // caught while building this endpoint (see JsonConventions.cs):
        // Results.Ok's default naming policy doesn't reach into embedded
        // JsonElement values, so the DB-stored JSON has to be written
        // camelCase in the first place for the two to actually match.
        Assert.True(chart.TryGetProperty("ayanamsa", out _));
        Assert.True(chart.TryGetProperty("nakshatra", out _));
        Assert.True(chart.TryGetProperty("ascendant", out var ascendant));
        Assert.True(ascendant.TryGetProperty("signIndex", out _));

        var d1 = chart.GetProperty("d1");
        Assert.Equal(9, d1.GetArrayLength());
        var sun = d1.EnumerateArray().Single(p => p.GetProperty("planet").GetString() == "Sun");
        Assert.True(sun.TryGetProperty("signIndex", out _));
        Assert.True(sun.TryGetProperty("degreeInSign", out _));
        Assert.True(sun.TryGetProperty("retrograde", out _));
        Assert.False(sun.TryGetProperty("Planet", out _)); // the PascalCase form must NOT be present

        Assert.Equal(9, chart.GetProperty("d9").GetArrayLength());
        Assert.Equal(9, chart.GetProperty("d10").GetArrayLength());
        Assert.Equal(9, chart.GetProperty("d60").GetArrayLength()); // known birth time -> D60 populated
        Assert.Equal(9, chart.GetProperty("kp").GetArrayLength());
        Assert.Equal(12, chart.GetProperty("cusps").GetArrayLength());
    }

    [Fact]
    public async Task GetChart_UnknownBirthTime_D60AndKpAndCuspsAreEmpty()
    {
        var client = await AuthedClientAsync("uid-chart-4");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Unknown Time", new DateOnly(1990, 5, 15), null, true,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var chart = await client.GetFromJsonAsync<JsonElement>("/chart");

        Assert.Equal(9, chart.GetProperty("d1").GetArrayLength()); // signs still computed
        Assert.Equal(0, chart.GetProperty("d60").GetArrayLength());
        Assert.Equal(0, chart.GetProperty("kp").GetArrayLength());
        Assert.Equal(0, chart.GetProperty("cusps").GetArrayLength());
    }

    [Fact]
    public async Task GetDasha_AfterBirthDataSaved_ReturnsCamelCaseMahaAntarPratyantar()
    {
        var client = await AuthedClientAsync("uid-chart-5");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Dasha Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var dasha = await client.GetFromJsonAsync<JsonElement>("/dasha");

        Assert.True(dasha.TryGetProperty("validMonth", out _));
        var maha = dasha.GetProperty("maha");
        Assert.Equal(9, maha.GetArrayLength());
        var firstEntry = maha.EnumerateArray().First();
        Assert.True(firstEntry.TryGetProperty("lord", out _));
        Assert.True(firstEntry.TryGetProperty("start", out _));
        Assert.True(firstEntry.TryGetProperty("current", out _));
        Assert.Contains(maha.EnumerateArray(), p => p.GetProperty("current").GetBoolean());
        Assert.Equal(9, dasha.GetProperty("antar").GetArrayLength());
        Assert.Equal(9, dasha.GetProperty("pratyantar").GetArrayLength());
    }

    // Regression test: the `current` flag on each stored period used to be a
    // snapshot frozen at the moment birth data was last (re)saved, with no
    // scheduled job to refresh it — so a user who saved birth data a while
    // ago would see a stale "current" Antardasha forever. GET /dasha now
    // recomputes `current` live from each period's own start/end instead of
    // trusting the stored flag (see ChartEndpoints.RefreshCurrentFlags).
    [Fact]
    public async Task GetDasha_WithStaleStoredCurrentFlag_RecomputesCurrentLiveFromStartEnd()
    {
        var client = await AuthedClientAsync("uid-chart-stale-dasha");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Stale Dasha Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));
        var me = await client.GetFromJsonAsync<JsonElement>("/me");
        var userId = me.GetProperty("id").GetGuid();

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var dasha = await db.Dashas.SingleAsync(d => d.UserId == userId);
            var maha = JsonSerializer.Deserialize<List<Dictionary<string, object>>>(dasha.MahaJson)!;

            // Simulate staleness: mark a period that ended long ago as
            // "current", and clear the flag on whichever period is actually
            // current right now — exactly what happens if the real "current"
            // period rolled over since the last birth-data save.
            var reallyCurrentIndex = maha.FindIndex(p => ((JsonElement)p["current"]).GetBoolean());
            maha[reallyCurrentIndex]["current"] = false;
            maha[0]["current"] = true; // the earliest period — long since ended

            dasha.MahaJson = JsonSerializer.Serialize(maha);
            await db.SaveChangesAsync();
        }

        var response = await client.GetFromJsonAsync<JsonElement>("/dasha");
        var refreshedMaha = response.GetProperty("maha").EnumerateArray().ToList();

        // The endpoint must not trust the stale stored flag — exactly one
        // period should read `current: true`, and it must be the one whose
        // start/end genuinely brackets right now, not the artificially
        // marked long-ended first period.
        var currentEntries = refreshedMaha.Where(p => p.GetProperty("current").GetBoolean()).ToList();
        Assert.Single(currentEntries);
        var now = DateTime.UtcNow;
        var start = currentEntries[0].GetProperty("start").GetDateTime();
        var end = currentEntries[0].GetProperty("end").GetDateTime();
        Assert.True(start <= now && now < end);
        Assert.False(refreshedMaha[0].GetProperty("current").GetBoolean());
    }

    [Fact]
    public async Task GetChartAndDasha_WithoutAuth_Return401()
    {
        var client = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/chart")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/dasha")).StatusCode);
    }
}

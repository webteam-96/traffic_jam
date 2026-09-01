using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using TrafficJam.Api.Modules.Astro;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class DoshaEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public DoshaEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

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
    public async Task GetDoshas_WithoutBirthData_Returns404()
    {
        var client = await AuthedClientAsync("uid-dosha-nodata");
        var response = await client.GetAsync("/doshas");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetDoshas_WithBirthDataSaved_ReturnsAllThreeSections()
    {
        var client = await AuthedClientAsync("uid-dosha-1");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Dosha Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var response = await client.GetAsync("/doshas");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();

        var mangal = body.GetProperty("mangal");
        Assert.True(mangal.TryGetProperty("fromLagna", out _));
        Assert.True(mangal.TryGetProperty("fromMoon", out _));
        Assert.True(mangal.TryGetProperty("fromVenus", out _));
        Assert.True(mangal.TryGetProperty("marsInOwnOrExaltedSign", out _));

        var kaalSarp = body.GetProperty("kaalSarp");
        Assert.True(kaalSarp.TryGetProperty("isPresent", out _));

        var sadeSati = body.GetProperty("sadeSati");
        Assert.True(sadeSati.TryGetProperty("isActive", out _));
    }

    [Fact]
    public async Task GetDoshas_UnknownBirthTime_MangalFromLagnaIsNullButOthersPopulated()
    {
        var client = await AuthedClientAsync("uid-dosha-unknowntime");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Unknown Time Dosha Test", new DateOnly(1990, 5, 15), null, true,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var body = await client.GetFromJsonAsync<JsonElement>("/doshas");

        var mangal = body.GetProperty("mangal");
        Assert.Equal(JsonValueKind.Null, mangal.GetProperty("fromLagna").ValueKind);
        Assert.Equal(JsonValueKind.Null, mangal.GetProperty("houseFromLagna").ValueKind);
        Assert.True(mangal.GetProperty("fromMoon").ValueKind is JsonValueKind.True or JsonValueKind.False);
    }

    [Fact]
    public async Task ComputeChart_IncludesDoshasForANonOwnBirthDate()
    {
        var client = await AuthedClientAsync("uid-dosha-compute");

        var response = await client.PostAsJsonAsync("/chart/compute", new ComputeChartRequest(
            new DateOnly(1975, 1, 1), new TimeOnly(6, 0), false, 28.6139, 77.2090, "Asia/Kolkata"));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();

        var doshas = body.GetProperty("doshas");
        Assert.True(doshas.GetProperty("mangal").TryGetProperty("fromMoon", out _));
        Assert.True(doshas.GetProperty("kaalSarp").TryGetProperty("isPresent", out _));
        Assert.True(doshas.GetProperty("sadeSati").TryGetProperty("isActive", out _));
    }

    [Fact]
    public async Task GetDoshas_WithoutAuth_Returns401()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/doshas");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}

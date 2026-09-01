using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class RemedyEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public RemedyEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

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
    public async Task GetRemedies_WithoutBirthData_ReturnsOnlyGeneralOnes()
    {
        var client = await AuthedClientAsync("uid-remedy-nodata");

        var remedies = await client.GetFromJsonAsync<JsonElement>("/remedies");

        Assert.True(remedies.GetArrayLength() > 0);
        Assert.All(remedies.EnumerateArray(),
            r => Assert.Equal("general", r.GetProperty("triggerRule").GetString()));
    }

    [Fact]
    public async Task GetRemedies_WithBirthDataSaved_IncludesCurrentDashaLordRemedies()
    {
        var client = await AuthedClientAsync("uid-remedy-withdata");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Remedy Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var dasha = await client.GetFromJsonAsync<JsonElement>("/dasha");
        var currentMahaLord = dasha.GetProperty("maha").EnumerateArray()
            .Single(p => p.GetProperty("current").GetBoolean()).GetProperty("lord").GetString();

        var remedies = await client.GetFromJsonAsync<JsonElement>("/remedies");
        var triggers = remedies.EnumerateArray().Select(r => r.GetProperty("triggerRule").GetString()).ToList();

        Assert.Contains("general", triggers);
        Assert.Contains(currentMahaLord, triggers);
    }

    [Fact]
    public async Task GetRemedies_EveryEntry_HasTypeTitleAndDetail()
    {
        var client = await AuthedClientAsync("uid-remedy-shape");

        var remedies = await client.GetFromJsonAsync<JsonElement>("/remedies");

        Assert.All(remedies.EnumerateArray(), r =>
        {
            Assert.False(string.IsNullOrWhiteSpace(r.GetProperty("type").GetString()));
            Assert.False(string.IsNullOrWhiteSpace(r.GetProperty("title").GetString()));
            Assert.False(string.IsNullOrWhiteSpace(r.GetProperty("detail").GetString()));
        });
    }

    [Fact]
    public async Task GetRemedies_WithoutAuth_Returns401()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/remedies");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}

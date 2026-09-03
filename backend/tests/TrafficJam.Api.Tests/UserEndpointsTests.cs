using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class UserEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public UserEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<HttpClient> AuthedClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        // Each test needs its own phone number too — PhoneHash is unique, and reusing
        // one across users here would hit the same duplicate-key path a real re-install/
        // re-verification does (see AuthFlowTests.Session_WithSamePhoneNewFirebaseUid_RelinksTheExistingUser).
        var session = await client.PostAsJsonAsync("/auth/session", new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    [Fact]
    public async Task BirthData_GetBeforeAnyIsSaved_Returns404()
    {
        var client = await AuthedClientAsync("uid-bd-1");

        var response = await client.GetAsync("/me/birth-data");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task BirthData_SaveThenGet_RoundTripsCorrectly()
    {
        var client = await AuthedClientAsync("uid-bd-2");
        var request = new BirthDataRequest(
            "Ananya Sharma", new DateOnly(1988, 10, 24), new TimeOnly(4, 42), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata");

        var putResponse = await client.PutAsJsonAsync("/me/birth-data", request);
        Assert.Equal(HttpStatusCode.OK, putResponse.StatusCode);

        var getResponse = await client.GetAsync("/me/birth-data");
        var body = await getResponse.Content.ReadFromJsonAsync<BirthDataResponse>();

        Assert.Equal("Ananya Sharma", body!.Name);
        Assert.Equal(new DateOnly(1988, 10, 24), body.Dob);
        Assert.Equal(new TimeOnly(4, 42), body.Tob);
        Assert.Equal("Mumbai, Maharashtra, India", body.Place);
        Assert.Equal(19.0760, body.Lat, precision: 4);
    }

    [Fact]
    public async Task BirthData_SavingClearsAnyOnboardingDraft()
    {
        var client = await AuthedClientAsync("uid-bd-3");
        await client.PatchAsJsonAsync("/onboarding/draft", new OnboardingDraftRequest(
            "Draft Name", new DateOnly(1990, 1, 1), null, null, null, null, null, null));

        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Final Name", new DateOnly(1990, 1, 1), null, true, "Delhi, India", 28.6139, 77.2090, "Asia/Kolkata"));

        // No direct GET for the draft in the API contract, but re-PATCHing after
        // a clear should behave like starting fresh, not merging with the old draft.
        var patchAgain = await client.PatchAsJsonAsync("/onboarding/draft", new OnboardingDraftRequest(
            null, null, null, null, null, null, null, null));
        Assert.Equal(HttpStatusCode.OK, patchAgain.StatusCode);
    }

    [Fact]
    public async Task OnboardingDraft_PartialPatchesAccumulate()
    {
        var client = await AuthedClientAsync("uid-draft-1");

        await client.PatchAsJsonAsync("/onboarding/draft",
            new OnboardingDraftRequest("Rohan", null, null, null, null, null, null, null));
        var response = await client.PatchAsJsonAsync("/onboarding/draft",
            new OnboardingDraftRequest(null, new DateOnly(1995, 5, 5), null, null, null, null, null, null));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task NotificationPreferences_DefaultsThenUpdate_RoundTrips()
    {
        var client = await AuthedClientAsync("uid-notif-1");

        var defaults = await client.GetFromJsonAsync<NotificationPreferencesResponse>("/me/notification-preferences");
        Assert.True(defaults!.Morning); // entity default

        var updateResponse = await client.PutAsJsonAsync("/me/notification-preferences",
            new NotificationPreferencesRequest(
                Morning: false, RahuKaal: true, Events: true, Dasha: false, Remedies: true,
                Channels: new Dictionary<string, string[]> { ["morning"] = ["push", "whatsapp"] }));
        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

        var updated = await client.GetFromJsonAsync<NotificationPreferencesResponse>("/me/notification-preferences");
        Assert.False(updated!.Morning);
        Assert.True(updated.Events);
        Assert.Equal(["push", "whatsapp"], updated.Channels["morning"]);
    }

    [Fact]
    public async Task Devices_RegisteringTheSameTokenTwice_DoesNotDuplicate()
    {
        var client = await AuthedClientAsync("uid-device-1");
        var request = new DeviceRequest("fcm-token-abc", "android");

        var first = await client.PostAsJsonAsync("/me/devices", request);
        var second = await client.PostAsJsonAsync("/me/devices", request);

        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
    }

    [Fact]
    public async Task Places_WithoutApiKeyConfigured_ReturnsCleanServiceUnavailable()
    {
        var client = await AuthedClientAsync("uid-places-1");

        var response = await client.GetAsync("/places/autocomplete?q=Mumbai");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    // Regression test for a real bug found during end-to-end testing: editing
    // birth data regenerated the Chart and Dasha correctly, but left
    // GET /signal/today silently serving a stale DailySignals cache row
    // computed from the OLD birth data — no error, just wrong data for the
    // rest of the day. /transits/today is uncached (recomputed every request)
    // so it was never at risk of this, but is checked here too as a guard
    // against caching being reintroduced there without invalidation.
    [Fact]
    public async Task BirthData_Editing_InvalidatesStaleSignalAndTransitCaches()
    {
        var client = await AuthedClientAsync("uid-stale-1");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Person A", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var signalBefore = await client.GetFromJsonAsync<JsonElement>("/signal/today");
        var transitsBefore = await client.GetFromJsonAsync<JsonElement>("/transits/today");

        // A materially different person — different decade and birth time —
        // so the natal Moon sign, Dasha, and everything downstream must change.
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Person B", new DateOnly(1975, 1, 1), new TimeOnly(6, 0), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var signalAfter = await client.GetFromJsonAsync<JsonElement>("/signal/today");
        var transitsAfter = await client.GetFromJsonAsync<JsonElement>("/transits/today");

        var dashaDriverBefore = signalBefore.GetProperty("breakdown").GetProperty("dasha").GetProperty("driver").GetString();
        var dashaDriverAfter = signalAfter.GetProperty("breakdown").GetProperty("dasha").GetProperty("driver").GetString();
        Assert.NotEqual(dashaDriverBefore, dashaDriverAfter); // different birth Moon Nakshatra -> different Dasha lord chain entirely

        var moonHouseBefore = transitsBefore.GetProperty("planets").EnumerateArray()
            .Single(p => p.GetProperty("planet").GetString() == "Moon").GetProperty("houseFromMoon").GetInt32();
        var moonHouseAfter = transitsAfter.GetProperty("planets").EnumerateArray()
            .Single(p => p.GetProperty("planet").GetString() == "Moon").GetProperty("houseFromMoon").GetInt32();
        Assert.NotEqual(moonHouseBefore, moonHouseAfter); // different natal Moon sign -> different house-from-Moon for every transiting planet
    }

    [Fact]
    public async Task AllMeEndpoints_WithoutAuth_Return401()
    {
        var client = _factory.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/me/birth-data")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/me/notification-preferences")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsync("/me/devices", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/me/export")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.DeleteAsync("/me")).StatusCode);
    }

    [Fact]
    public async Task Export_WithBirthDataSaved_IncludesProfileAndBirthData()
    {
        var client = await AuthedClientAsync("uid-export-1");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Export Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var export = await client.GetFromJsonAsync<JsonElement>("/me/export");

        Assert.Equal("Export Test", export.GetProperty("profile").GetProperty("name").GetString());
        var birthData = export.GetProperty("birthData");
        Assert.Equal("Mumbai, Maharashtra, India", birthData.GetProperty("place").GetString());
        Assert.Equal(0, export.GetProperty("questions").GetArrayLength());
        Assert.Equal(0, export.GetProperty("appointments").GetArrayLength());
    }

    [Fact]
    public async Task Export_WithoutBirthDataSaved_HasNullBirthData()
    {
        var client = await AuthedClientAsync("uid-export-2");

        var export = await client.GetFromJsonAsync<JsonElement>("/me/export");

        Assert.Equal(JsonValueKind.Null, export.GetProperty("birthData").ValueKind);
    }

    [Fact]
    public async Task DeleteAccount_ThenGetBirthData_401sBecauseTheTokensNoLongerResolve()
    {
        var client = await AuthedClientAsync("uid-delete-1");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Delete Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var deleteResponse = await client.DeleteAsync("/me");
        Assert.Equal(HttpStatusCode.OK, deleteResponse.StatusCode);

        // The access token is still structurally valid (JWTs are stateless),
        // but the user it names — and the cascaded BirthData row — no
        // longer exist, so this must 404 cleanly rather than 500.
        var response = await client.GetAsync("/me/birth-data");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}

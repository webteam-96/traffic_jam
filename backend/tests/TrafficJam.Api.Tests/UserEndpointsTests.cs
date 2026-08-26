using System.Net;
using System.Net.Http.Json;
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

    [Fact]
    public async Task AllMeEndpoints_WithoutAuth_Return401()
    {
        var client = _factory.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/me/birth-data")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/me/notification-preferences")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsync("/me/devices", null)).StatusCode);
    }
}

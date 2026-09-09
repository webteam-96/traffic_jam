using System.Net;
using System.Net.Http.Json;
using TrafficJam.Api.Modules.Auth;
using Xunit;

namespace TrafficJam.Api.Tests;

public class AuthFlowTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public AuthFlowTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task DevLogin_WithCorrectOtp_IssuesTokens()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest("+919999999999", "123456"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<SessionResponse>();
        Assert.False(string.IsNullOrWhiteSpace(body!.AccessToken));
    }

    [Fact]
    public async Task DevLogin_WithWrongOtp_Returns401()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest("+919999999999", "000000"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DevLogin_WithSamePhoneTwice_ReturnsTheSameUser()
    {
        var client = _factory.CreateClient();
        var request = new DevLoginRequest("+919999999999", "123456");

        var first = await AuthedMeAsync(client, await client.PostAsJsonAsync("/auth/dev-login", request));
        var second = await AuthedMeAsync(client, await client.PostAsJsonAsync("/auth/dev-login", request));

        Assert.Equal(first.Id, second.Id);
    }

    [Fact]
    public async Task Session_WithNewUser_CreatesUserAndIssuesTokens()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/session",
            new SessionRequest("uid-new-user:+919876500001"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<SessionResponse>();
        Assert.NotNull(body);
        Assert.False(string.IsNullOrWhiteSpace(body!.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(body.RefreshToken));
    }

    [Fact]
    public async Task Session_WithSameFirebaseUidTwice_ReturnsTheSameUser()
    {
        var client = _factory.CreateClient();

        var first = await client.PostAsJsonAsync("/auth/session", new SessionRequest("uid-repeat:+919876500002"));
        var firstMe = await AuthedMeAsync(client, first);

        var second = await client.PostAsJsonAsync("/auth/session", new SessionRequest("uid-repeat:+919876500002"));
        var secondMe = await AuthedMeAsync(client, second);

        Assert.Equal(firstMe.Id, secondMe.Id);
    }

    [Fact]
    public async Task Me_WithValidAccessToken_ReturnsTheUser()
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session", new SessionRequest("uid-me:+919876500003"));

        var me = await AuthedMeAsync(client, session);

        Assert.False(me.OnboardingComplete); // no BirthData saved yet
    }

    [Fact]
    public async Task Me_WithoutToken_Returns401()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Refresh_WithValidToken_IssuesNewTokensAndRevokesTheOldOne()
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session", new SessionRequest("uid-refresh:+919876500004"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();

        var refreshed = await client.PostAsJsonAsync("/auth/refresh", new RefreshRequest(tokens!.RefreshToken));
        Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
        var newTokens = await refreshed.Content.ReadFromJsonAsync<SessionResponse>();
        Assert.NotEqual(tokens.AccessToken, newTokens!.AccessToken);

        // Redeeming the same (now-rotated) refresh token again must fail.
        var reused = await client.PostAsJsonAsync("/auth/refresh", new RefreshRequest(tokens.RefreshToken));
        Assert.Equal(HttpStatusCode.Unauthorized, reused.StatusCode);
    }

    [Fact]
    public async Task Session_WithSamePhoneNewFirebaseUid_RelinksTheExistingUserInsteadOfCrashing()
    {
        var client = _factory.CreateClient();
        var samePhone = "+919876500005";

        var first = await client.PostAsJsonAsync("/auth/session", new SessionRequest($"uid-original:{samePhone}"));
        var firstMe = await AuthedMeAsync(client, first);

        // Same phone, different Firebase UID — reinstall/re-verification, not a new person.
        var second = await client.PostAsJsonAsync("/auth/session", new SessionRequest($"uid-reinstalled:{samePhone}"));
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        var secondMe = await AuthedMeAsync(client, second);

        Assert.Equal(firstMe.Id, secondMe.Id); // re-linked to the same user, not a crash or a duplicate
    }

    [Fact]
    public async Task Session_WithMalformedFakeToken_Returns401()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/session", new SessionRequest("not-a-valid-token"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static async Task<MeResponse> AuthedMeAsync(HttpClient client, HttpResponseMessage sessionResponse)
    {
        var tokens = await sessionResponse.Content.ReadFromJsonAsync<SessionResponse>();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/me");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<MeResponse>())!;
    }

    // Two codes: the App Review account has its own, everyone else shares the
    // other. Apple's submission form publishes the review credentials, so the
    // code written there must not open any other number.
    [Fact]
    public async Task DevLogin_ReviewAccount_SignsInWithItsOwnCode()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest("+919999999999", "123456"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("+919812345678")]
    [InlineData("+910000000000")]
    public async Task DevLogin_AnyOtherNumber_SignsInWithTheGeneralCode(string phone)
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest(phone, "654321"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // The crossover cases are the point of having two codes at all: neither
    // works where the other belongs.
    [Theory]
    [InlineData("+919812345678", "123456")]   // review code, ordinary number
    [InlineData("+919999999999", "654321")]   // general code, review number
    [InlineData("+919812345678", "000000")]
    public async Task DevLogin_WithTheWrongCodeForThatNumber_Is401(string phone, string otp)
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest(phone, otp));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // The rejection must not name the code it wanted — the original message
    // printed it outright, which handed the whole mechanism to anyone who
    // mistyped a digit once.
    [Fact]
    public async Task DevLogin_Rejection_DoesNotRevealTheExpectedCode()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest("+919812345679", "000000"));
        var body = await response.Content.ReadAsStringAsync();

        Assert.DoesNotContain("123456", body);
        Assert.DoesNotContain("654321", body);
    }

    // Both rejections read identically. A different message for "wrong code
    // for the review account" would tell you which account you just probed.
    [Fact]
    public async Task DevLogin_Rejections_ReadTheSameWhicheverCodeWasWrong()
    {
        var client = _factory.CreateClient();

        var reviewNumber = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest("+919999999999", "654321"));
        var ordinaryNumber = await client.PostAsJsonAsync("/auth/dev-login",
            new DevLoginRequest("+919812345678", "123456"));

        Assert.Equal(reviewNumber.StatusCode, ordinaryNumber.StatusCode);
        Assert.Equal(
            await reviewNumber.Content.ReadAsStringAsync(),
            await ordinaryNumber.Content.ReadAsStringAsync());
    }
}

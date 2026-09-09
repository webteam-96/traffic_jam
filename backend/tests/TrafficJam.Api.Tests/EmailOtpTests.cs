using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Modules.Auth;
using Xunit;

namespace TrafficJam.Api.Tests;

/// <summary>
/// Email sign-in. Built but not yet wired into the app, so these tests are the
/// only thing exercising it — which makes the security properties worth
/// pinning explicitly rather than trusting they hold.
/// </summary>
public class EmailOtpTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public EmailOtpTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    /// <summary>
    /// Codes are only ever stored hashed, so a test can't read one back — it
    /// reaches into the service the same way verification does.
    /// </summary>
    private async Task<string> IssueAndRecoverCodeAsync(HttpClient client, string email)
    {
        var response = await client.PostAsJsonAsync("/auth/email/request-otp", new EmailOtpRequest(email));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        // Brute-force the six digits against the stored hash. Only viable
        // because the test knows the salt; that it takes a million tries is
        // rather the point of storing them this way.
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hash = EmailHasher.Hash(email);
        var otp = await db.EmailOtps.AsNoTracking()
            .Where(o => o.EmailHash == hash && o.ConsumedAt == null)
            .OrderByDescending(o => o.CreatedAt)
            .FirstAsync();

        for (var i = 0; i < 1_000_000; i++)
        {
            var candidate = i.ToString("D6");
            var digest = Convert.ToHexStringLower(
                System.Security.Cryptography.SHA256.HashData(
                    System.Text.Encoding.UTF8.GetBytes($"{hash}:{candidate}")));
            if (digest == otp.CodeHash) return candidate;
        }

        throw new InvalidOperationException("Couldn't recover the issued code.");
    }

    [Fact]
    public async Task RequestThenVerify_SignsTheUserIn()
    {
        var client = _factory.CreateClient();
        const string email = "reader@example.com";

        var code = await IssueAndRecoverCodeAsync(client, email);

        var verify = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest(email, code));

        Assert.Equal(HttpStatusCode.OK, verify.StatusCode);
        var session = await verify.Content.ReadFromJsonAsync<SessionResponse>();
        Assert.False(string.IsNullOrWhiteSpace(session!.AccessToken));

        // And the token actually works.
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", session.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/me")).StatusCode);
    }

    // Single use. A code that still works after sign-in is a code that works
    // for whoever else has seen the email.
    [Fact]
    public async Task AVerifiedCode_CannotBeUsedTwice()
    {
        var client = _factory.CreateClient();
        const string email = "replay@example.com";

        var code = await IssueAndRecoverCodeAsync(client, email);
        Assert.Equal(HttpStatusCode.OK,
            (await client.PostAsJsonAsync("/auth/email/verify-otp", new EmailOtpVerifyRequest(email, code))).StatusCode);

        var second = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest(email, code));

        Assert.Equal(HttpStatusCode.Unauthorized, second.StatusCode);
    }

    // Requesting a second code must invalidate the first, or a stack of valid
    // codes accumulates.
    [Fact]
    public async Task RequestingAgain_InvalidatesTheEarlierCode()
    {
        var client = _factory.CreateClient();
        const string email = "reissue@example.com";

        var first = await IssueAndRecoverCodeAsync(client, email);
        await ClearCooldownAsync();
        var second = await IssueAndRecoverCodeAsync(client, email);
        Assert.NotEqual(first, second);

        var withOld = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest(email, first));
        Assert.Equal(HttpStatusCode.Unauthorized, withOld.StatusCode);

        var withNew = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest(email, second));
        Assert.Equal(HttpStatusCode.OK, withNew.StatusCode);
    }

    // Six digits is a million possibilities — but only if guessing costs
    // something. Five wrong tries burns the code.
    [Fact]
    public async Task FiveWrongGuesses_BurnsTheCode()
    {
        var client = _factory.CreateClient();
        const string email = "bruteforce@example.com";

        var code = await IssueAndRecoverCodeAsync(client, email);
        var wrong = code == "000000" ? "111111" : "000000";

        for (var i = 0; i < 5; i++)
        {
            await client.PostAsJsonAsync("/auth/email/verify-otp", new EmailOtpVerifyRequest(email, wrong));
        }

        // Even the RIGHT code no longer works.
        var withCorrect = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest(email, code));
        Assert.Equal(HttpStatusCode.Unauthorized, withCorrect.StatusCode);
    }

    // The plaintext code must not be recoverable from the table.
    [Fact]
    public async Task TheCodeIsNeverStoredInPlaintext()
    {
        var client = _factory.CreateClient();
        const string email = "storage@example.com";

        var code = await IssueAndRecoverCodeAsync(client, email);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var stored = await db.EmailOtps.AsNoTracking()
            .Where(o => o.EmailHash == EmailHasher.Hash(email))
            .OrderByDescending(o => o.CreatedAt)
            .FirstAsync();

        Assert.NotEqual(code, stored.CodeHash);
        Assert.DoesNotContain(code, stored.CodeHash);
        Assert.Equal(64, stored.CodeHash.Length); // SHA-256 hex
    }

    // Two people given the same six digits must not share a stored hash.
    [Fact]
    public async Task TheSameCodeForTwoAddresses_HashesDifferently()
    {
        var a = EmailHasher.Hash("one@example.com");
        var b = EmailHasher.Hash("two@example.com");

        Assert.NotEqual(a, b);
    }

    // "Jay@Example.COM" and "jay@example.com" are one mailbox. Without
    // normalising, they would hash differently and quietly become two accounts
    // for the same person.
    [Theory]
    [InlineData("NORMALISE@Example.COM")]
    [InlineData("  normalise@example.com  ")]
    public async Task AddressesAreNormalised_SoOnePersonGetsOneAccount(string variant)
    {
        await ClearCooldownAsync();
        var client = _factory.CreateClient();

        var code = await IssueAndRecoverCodeAsync(client, "normalise@example.com");

        // A differently-cased or padded spelling of the same address verifies.
        var verify = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest(variant, code));

        Assert.Equal(HttpStatusCode.OK, verify.StatusCode);
    }

    // Signing in twice with the same address must reuse the account, not
    // create a second one — the unique index would throw, but this pins the
    // intent rather than the database's last line of defence.
    [Fact]
    public async Task SigningInTwice_ReusesTheSameAccount()
    {
        var client = _factory.CreateClient();
        const string email = "returning@example.com";

        var first = await IssueAndRecoverCodeAsync(client, email);
        await client.PostAsJsonAsync("/auth/email/verify-otp", new EmailOtpVerifyRequest(email, first));
        await ClearCooldownAsync();
        var second = await IssueAndRecoverCodeAsync(client, email);
        await client.PostAsJsonAsync("/auth/email/verify-otp", new EmailOtpVerifyRequest(email, second));

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var count = await db.Users.CountAsync(u => u.EmailHash == EmailHasher.Hash(email));

        Assert.Equal(1, count);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-an-email")]
    [InlineData("missing@domain")]
    [InlineData("@example.com")]
    public async Task MalformedAddresses_AreRejected(string email)
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/email/request-otp", new EmailOtpRequest(email));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    // Asking for a code for an unknown address must look exactly like asking
    // for a known one, or the endpoint becomes a way to enumerate users.
    [Fact]
    public async Task RequestingACode_LooksTheSameForKnownAndUnknownAddresses()
    {
        var client = _factory.CreateClient();

        var unknown = await client.PostAsJsonAsync("/auth/email/request-otp",
            new EmailOtpRequest("never-seen@example.com"));
        await ClearCooldownAsync();

        var known = await IssueAndRecoverCodeAsync(client, "known@example.com");
        await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest("known@example.com", known));
        await ClearCooldownAsync();

        var knownAgain = await client.PostAsJsonAsync("/auth/email/request-otp",
            new EmailOtpRequest("known@example.com"));

        Assert.Equal(unknown.StatusCode, knownAgain.StatusCode);
        Assert.Equal(
            await unknown.Content.ReadAsStringAsync(),
            await knownAgain.Content.ReadAsStringAsync());
    }

    // Verification failures must not distinguish "wrong code" from "no code
    // was ever requested for that address".
    [Fact]
    public async Task VerifyFailures_DoNotRevealWhetherACodeExists()
    {
        var client = _factory.CreateClient();
        const string email = "vague@example.com";

        var code = await IssueAndRecoverCodeAsync(client, email);
        var wrongCode = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest(email, code == "000000" ? "111111" : "000000"));
        var noCodeAtAll = await client.PostAsJsonAsync("/auth/email/verify-otp",
            new EmailOtpVerifyRequest("nothing-here@example.com", "123456"));

        Assert.Equal(wrongCode.StatusCode, noCodeAtAll.StatusCode);
        Assert.Equal(
            await wrongCode.Content.ReadAsStringAsync(),
            await noCodeAtAll.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task RequestingTwiceInARow_IsRateLimited()
    {
        var client = _factory.CreateClient();
        const string email = "flood@example.com";

        await client.PostAsJsonAsync("/auth/email/request-otp", new EmailOtpRequest(email));
        var second = await client.PostAsJsonAsync("/auth/email/request-otp", new EmailOtpRequest(email));

        Assert.Equal(HttpStatusCode.TooManyRequests, second.StatusCode);
    }

    /// <summary>
    /// The resend cooldown lives in IMemoryCache, which persists across
    /// requests in a test host — cleared so a test can issue twice without
    /// waiting 30 real seconds.
    /// </summary>
    private Task ClearCooldownAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var cache = scope.ServiceProvider
            .GetRequiredService<Microsoft.Extensions.Caching.Memory.IMemoryCache>();
        if (cache is Microsoft.Extensions.Caching.Memory.MemoryCache concrete)
        {
            concrete.Clear();
        }

        return Task.CompletedTask;
    }
}

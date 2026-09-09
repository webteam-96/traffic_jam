using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using TrafficJam.Api.Modules.Admin;
using TrafficJam.Api.Modules.Astrologer;
using TrafficJam.Api.Modules.Auth;
using Xunit;

namespace TrafficJam.Api.Tests;

/// <summary>
/// The About Jay screen's content, which used to be hardcoded in the app.
/// What matters here is that the admin's edits actually reach the app, and
/// that the two sides agree on the storage shape (newline-separated text in,
/// lists out).
/// </summary>
public class AstrologerEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public AstrologerEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<HttpClient> AppClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session",
            new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    private async Task<HttpClient> AdminClientAsync()
    {
        var client = _factory.CreateClient();
        var login = await client.PostAsJsonAsync("/admin/auth/login",
            new AdminLoginRequest("admin@trafficjam.life", "TrafficJam2026!"));
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var tokens = await login.Content.ReadFromJsonAsync<AdminLoginResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    [Fact]
    public async Task Get_ReturnsTheSeededProfileSoTheScreenIsNeverBlank()
    {
        var client = await AppClientAsync("uid-astro-1");

        var profile = await client.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");

        Assert.Equal("Jay Kotecha", profile!.Name);
        Assert.NotEmpty(profile.Bio);
        Assert.NotEmpty(profile.Expertise);
        Assert.NotEmpty(profile.Reviews);
    }

    // The storage shape is newline-separated text so the admin can add or
    // remove a paragraph without a schema change; the app receives a list.
    [Fact]
    public async Task Get_SplitsBioAndExpertiseIntoLines()
    {
        var client = await AppClientAsync("uid-astro-2");

        var profile = await client.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");

        Assert.True(profile!.Bio.Count > 1);
        Assert.All(profile.Bio, paragraph => Assert.False(paragraph.Contains('\n')));
        Assert.All(profile.Expertise, area => Assert.False(string.IsNullOrWhiteSpace(area)));
    }

    [Fact]
    public async Task Get_RequiresAuthentication()
    {
        var response = await _factory.CreateClient().GetAsync("/astrologer");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // The whole point: an admin edit shows up in the app without a release.
    [Fact]
    public async Task AdminEdit_IsVisibleToTheApp()
    {
        var admin = await AdminClientAsync();
        var app = await AppClientAsync("uid-astro-3");

        await admin.PutAsJsonAsync("/admin/astrologer", new AdminAstrologerProfileRequest(
            Name: "Jay Kotecha", Title: "Chief Astrologer",
            Bio: "First paragraph.\nSecond paragraph.",
            Philosophy: "A new philosophy.",
            Expertise: "KP System\nPrashna",
            ImageDataUri: null));

        var profile = await app.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");

        Assert.Equal("Chief Astrologer", profile!.Title);
        Assert.Equal(["First paragraph.", "Second paragraph."], profile.Bio);
        Assert.Equal("A new philosophy.", profile.Philosophy);
        Assert.Equal(["KP System", "Prashna"], profile.Expertise);
    }

    // A null image means "leave the photo alone". Without this, saving a text
    // edit from the admin form would silently wipe the uploaded portrait.
    [Fact]
    public async Task AdminEdit_WithNullImage_KeepsTheExistingPhoto()
    {
        var admin = await AdminClientAsync();
        var app = await AppClientAsync("uid-astro-4");
        const string photo = "data:image/png;base64,iVBORw0KGgo=";

        await admin.PutAsJsonAsync("/admin/astrologer", new AdminAstrologerProfileRequest(
            "Jay", "Astrologer", "Bio.", "Philosophy.", "KP", photo));
        await admin.PutAsJsonAsync("/admin/astrologer", new AdminAstrologerProfileRequest(
            "Jay", "Edited title", "Bio.", "Philosophy.", "KP", null));

        var profile = await app.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");

        Assert.Equal("Edited title", profile!.Title);
        Assert.Equal(photo, profile.ImageDataUri);
    }

    // An empty string is the explicit "remove the photo" signal, distinct from
    // null. Conflating the two would make the Remove photo button impossible.
    [Fact]
    public async Task AdminEdit_WithEmptyImage_ClearsThePhoto()
    {
        var admin = await AdminClientAsync();
        var app = await AppClientAsync("uid-astro-5");

        await admin.PutAsJsonAsync("/admin/astrologer", new AdminAstrologerProfileRequest(
            "Jay", "Astrologer", "Bio.", "Philosophy.", "KP", "data:image/png;base64,iVBORw0KGgo="));
        await admin.PutAsJsonAsync("/admin/astrologer", new AdminAstrologerProfileRequest(
            "Jay", "Astrologer", "Bio.", "Philosophy.", "KP", ""));

        var profile = await app.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");

        Assert.Null(profile!.ImageDataUri);
    }

    // The admin panel crops to 400x400 before upload, so anything near this
    // ceiling means something bypassed the cropper.
    [Fact]
    public async Task AdminEdit_WithAnOversizedPhoto_IsRejectedWithAMessage()
    {
        var admin = await AdminClientAsync();

        var response = await admin.PutAsJsonAsync("/admin/astrologer", new AdminAstrologerProfileRequest(
            "Jay", "Astrologer", "Bio.", "Philosophy.", "KP",
            "data:image/png;base64," + new string('A', 400_001)));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AdminReviews_AddEditAndDelete_FlowThroughToTheApp()
    {
        var admin = await AdminClientAsync();
        var app = await AppClientAsync("uid-astro-6");

        var created = await admin.PostAsJsonAsync("/admin/astrologer/reviews",
            new AdminAstrologerReviewRequest("A brand new review.", "Test Client", 99));
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);

        var profile = await app.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        var review = profile!.Reviews.Single(r => r.Author == "Test Client");
        Assert.Equal("A brand new review.", review.Quote);

        await admin.PutAsJsonAsync($"/admin/astrologer/reviews/{review.Id}",
            new AdminAstrologerReviewRequest("An edited review.", "Test Client", 99));
        profile = await app.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        Assert.Equal("An edited review.", profile!.Reviews.Single(r => r.Id == review.Id).Quote);

        await admin.DeleteAsync($"/admin/astrologer/reviews/{review.Id}");
        profile = await app.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        Assert.DoesNotContain(profile!.Reviews, r => r.Id == review.Id);
    }

    // SortOrder is the admin's ordering control; insertion order must not win.
    [Fact]
    public async Task Reviews_AreReturnedInTheAdminsChosenOrder()
    {
        var admin = await AdminClientAsync();
        var app = await AppClientAsync("uid-astro-7");

        await admin.PostAsJsonAsync("/admin/astrologer/reviews",
            new AdminAstrologerReviewRequest("Added first, shown last.", "Zeta", 900));
        await admin.PostAsJsonAsync("/admin/astrologer/reviews",
            new AdminAstrologerReviewRequest("Added second, shown first.", "Alpha", -1));

        var profile = await app.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");

        Assert.Equal("Alpha", profile!.Reviews.First().Author);
        Assert.Equal("Zeta", profile.Reviews.Last().Author);
    }

    [Fact]
    public async Task AdminEndpoints_RejectANonAdminToken()
    {
        var app = await AppClientAsync("uid-astro-8");

        var response = await app.PutAsJsonAsync("/admin/astrologer", new AdminAstrologerProfileRequest(
            "Impostor", "Hacker", "Bio.", "Philosophy.", "KP", null));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    // ── User-submitted reviews ───────────────────────────────────────────
    //
    // The gate that matters: a user can type anything, and none of it reaches
    // another user until the team approves it.

    [Fact]
    public async Task SubmittedReview_IsNotVisibleToAnyoneUntilApproved()
    {
        var author = await AppClientAsync("uid-review-1");
        var reader = await AppClientAsync("uid-review-2");

        var submit = await author.PostAsJsonAsync("/reviews",
            new SubmitReviewRequest("Genuinely useful reading, thank you.", 5));
        Assert.Equal(HttpStatusCode.OK, submit.StatusCode);

        var seenByReader = await reader.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        Assert.DoesNotContain(seenByReader!.Reviews, r => r.Quote.StartsWith("Genuinely useful"));

        // ...and not to its own author either, on the public list.
        var seenByAuthor = await author.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        Assert.DoesNotContain(seenByAuthor!.Reviews, r => r.Quote.StartsWith("Genuinely useful"));
    }

    [Fact]
    public async Task ApprovedReview_BecomesVisibleToEveryone()
    {
        var author = await AppClientAsync("uid-review-3");
        var reader = await AppClientAsync("uid-review-4");
        var admin = await AdminClientAsync();

        await author.PostAsJsonAsync("/reviews",
            new SubmitReviewRequest("The Dasha timing was spot on.", 5));

        var queue = await admin.GetFromJsonAsync<JsonElement>("/admin/astrologer");
        var pending = queue.GetProperty("reviews").EnumerateArray()
            .Single(r => r.GetProperty("quote").GetString()!.StartsWith("The Dasha timing"));
        Assert.Equal("Pending", pending.GetProperty("status").GetString());
        Assert.True(pending.GetProperty("isFromUser").GetBoolean());

        var id = pending.GetProperty("id").GetGuid();
        await admin.PostAsJsonAsync($"/admin/astrologer/reviews/{id}/approve", new { });

        var seen = await reader.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        var published = seen!.Reviews.Single(r => r.Id == id);
        Assert.Equal("The Dasha timing was spot on.", published.Quote);
        Assert.Equal(5, published.Rating);
    }

    [Fact]
    public async Task RejectedReview_StaysHidden()
    {
        var author = await AppClientAsync("uid-review-5");
        var admin = await AdminClientAsync();

        await author.PostAsJsonAsync("/reviews",
            new SubmitReviewRequest("A review that will be rejected.", 1));

        var queue = await admin.GetFromJsonAsync<JsonElement>("/admin/astrologer");
        var id = queue.GetProperty("reviews").EnumerateArray()
            .Single(r => r.GetProperty("quote").GetString()!.StartsWith("A review that will be"))
            .GetProperty("id").GetGuid();

        await admin.PostAsJsonAsync($"/admin/astrologer/reviews/{id}/reject", new { });

        var seen = await author.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        Assert.DoesNotContain(seen!.Reviews, r => r.Id == id);
    }

    // The author sees their own submission's state — otherwise a pending
    // review looks like it was never sent.
    [Fact]
    public async Task MyReview_ReportsItsOwnStatusBackToItsAuthor()
    {
        var author = await AppClientAsync("uid-review-6");

        var before = await author.GetAsync("/reviews/mine");
        Assert.Equal(HttpStatusCode.NoContent, before.StatusCode);

        await author.PostAsJsonAsync("/reviews",
            new SubmitReviewRequest("Waiting to hear back on this one.", 4));

        var mine = await author.GetFromJsonAsync<MyReviewResponse>("/reviews/mine");
        Assert.Equal("Pending", mine!.Status);
        Assert.Equal(4, mine.Rating);
    }

    // Resubmitting replaces rather than stacking, so one person can't fill the
    // page with their own reviews.
    [Fact]
    public async Task Resubmitting_ReplacesTheEarlierPendingReview()
    {
        var author = await AppClientAsync("uid-review-7");
        var admin = await AdminClientAsync();

        await author.PostAsJsonAsync("/reviews", new SubmitReviewRequest("First attempt at this.", 3));
        await author.PostAsJsonAsync("/reviews", new SubmitReviewRequest("Second, better attempt.", 5));

        // Scoped to this author's own text: the shared test database keeps
        // rows from earlier tests in the class (ResetDatabaseAsync creates the
        // schema once, it isn't a per-test truncate), so "every user review"
        // would be counting other tests' submissions.
        var queue = await admin.GetFromJsonAsync<JsonElement>("/admin/astrologer");
        var quotes = queue.GetProperty("reviews").EnumerateArray()
            .Select(r => r.GetProperty("quote").GetString()!)
            .ToList();

        Assert.DoesNotContain("First attempt at this.", quotes);
        Assert.Contains("Second, better attempt.", quotes);
    }

    // Once published, a review can't be quietly rewritten into something the
    // team never vetted.
    [Fact]
    public async Task Resubmitting_AfterApproval_IsRefused()
    {
        var author = await AppClientAsync("uid-review-8");
        var admin = await AdminClientAsync();

        await author.PostAsJsonAsync("/reviews", new SubmitReviewRequest("An honest first review.", 5));
        var queue = await admin.GetFromJsonAsync<JsonElement>("/admin/astrologer");
        var id = queue.GetProperty("reviews").EnumerateArray()
            .Single(r => r.GetProperty("quote").GetString()!.StartsWith("An honest first"))
            .GetProperty("id").GetGuid();
        await admin.PostAsJsonAsync($"/admin/astrologer/reviews/{id}/approve", new { });

        var again = await author.PostAsJsonAsync("/reviews",
            new SubmitReviewRequest("Something completely different now.", 1));

        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
    }

    [Theory]
    [InlineData("short", 5)]                                  // below the minimum length
    [InlineData("A perfectly reasonable review here.", 0)]    // rating out of range
    [InlineData("A perfectly reasonable review here.", 6)]
    public async Task Submit_RejectsInvalidInput(string quote, int rating)
    {
        var author = await AppClientAsync("uid-review-9");

        var response = await author.PostAsJsonAsync("/reviews", new SubmitReviewRequest(quote, rating));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Submit_RequiresAuthentication()
    {
        var response = await _factory.CreateClient().PostAsJsonAsync("/reviews",
            new SubmitReviewRequest("An anonymous review attempt.", 5));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // Team-authored testimonials are written by the moderators, so they skip
    // the queue rather than sitting in it waiting for themselves.
    [Fact]
    public async Task AdminAuthoredReview_IsPublishedImmediately()
    {
        var admin = await AdminClientAsync();
        var reader = await AppClientAsync("uid-review-10");

        await admin.PostAsJsonAsync("/admin/astrologer/reviews",
            new AdminAstrologerReviewRequest("Written by the team.", "Team", 5));

        var seen = await reader.GetFromJsonAsync<AstrologerProfileResponse>("/astrologer");
        Assert.Contains(seen!.Reviews, r => r.Quote == "Written by the team.");
    }
}

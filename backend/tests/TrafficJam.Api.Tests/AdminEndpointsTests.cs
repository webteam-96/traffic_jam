using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Modules.Admin;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Consultation;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class AdminEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public AdminEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<HttpClient> AuthedUserClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session", new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    private async Task<HttpClient> AuthedAdminClientAsync()
    {
        var client = _factory.CreateClient();
        var login = await client.PostAsJsonAsync("/admin/auth/login",
            new AdminLoginRequest("admin@trafficjam.life", "TrafficJam2026!"));
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var body = await login.Content.ReadFromJsonAsync<AdminLoginResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", body!.AccessToken);
        return client;
    }

    private async Task GrantSagaPlusAsync(string uid, BillingCycle cycle)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var userId = await db.Users.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        db.Subscriptions.Add(new Subscription
        {
            UserId = userId, Tier = SubscriptionTier.SagaPlus, Cycle = cycle,
            RenewsAt = DateTime.UtcNow.AddDays(30),
        });
        await db.SaveChangesAsync();
    }

    // ── Auth ─────────────────────────────────────────────────────────────

    [Fact]
    public async Task Login_WithSeededDevCredentials_Succeeds()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/admin/auth/login",
            new AdminLoginRequest("admin@trafficjam.life", "TrafficJam2026!"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<AdminLoginResponse>();
        Assert.Equal("admin@trafficjam.life", body!.Email);
    }

    [Fact]
    public async Task Login_WithWrongPassword_Returns401()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/admin/auth/login",
            new AdminLoginRequest("admin@trafficjam.life", "wrong-password"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Login_WithUnknownEmail_Returns401NotFound()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/admin/auth/login",
            new AdminLoginRequest("nobody@trafficjam.life", "whatever"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task RegularUserToken_CannotAccessAdminEndpoints()
    {
        var userClient = await AuthedUserClientAsync("uid-admin-guard-1");
        var response = await userClient.GetAsync("/admin/dashboard/summary");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task AdminToken_CannotAccessRegularUserEndpoints()
    {
        // An admin JWT has no consumer User row behind its NameIdentifier,
        // so principal.UserId() resolving against db.Users must fail
        // cleanly (not 200 with nonsense data) if ever pointed at a
        // consumer endpoint.
        var adminClient = await AuthedAdminClientAsync();
        var response = await adminClient.GetAsync("/me/birth-data");
        Assert.NotEqual(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Me_ReturnsTheLoggedInAdmin()
    {
        var client = await AuthedAdminClientAsync();
        var me = await client.GetFromJsonAsync<AdminMeResponse>("/admin/auth/me");
        Assert.Equal("admin@trafficjam.life", me!.Email);
    }

    // ── Dashboard ────────────────────────────────────────────────────────

    [Fact]
    public async Task Dashboard_ReflectsRealCounts()
    {
        var user = await AuthedUserClientAsync("uid-admin-dash-1");
        await user.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Dash Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));
        await user.PostAsJsonAsync("/consult/questions", new AskQuestionRequest("career", "Q?", "standard"));

        var admin = await AuthedAdminClientAsync();
        var summary = await admin.GetFromJsonAsync<AdminDashboardSummary>("/admin/dashboard/summary");

        Assert.True(summary!.TotalUsers >= 1);
        Assert.True(summary.UsersWithBirthData >= 1);
        Assert.True(summary.PendingQuestions >= 1);
    }

    [Fact]
    public async Task Dashboard_WithoutAdminAuth_Returns401()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/admin/dashboard/summary");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // ── Users ────────────────────────────────────────────────────────────

    [Fact]
    public async Task ListUsers_IncludesARealUser()
    {
        var user = await AuthedUserClientAsync("uid-admin-users-1");
        var me = await user.GetFromJsonAsync<JsonElement>("/me");
        var userId = me.GetProperty("id").GetGuid();

        var admin = await AuthedAdminClientAsync();
        var list = await admin.GetFromJsonAsync<AdminUserListResponse>("/admin/users?page=1&pageSize=50");

        Assert.Contains(list!.Users, u => u.Id == userId);
    }

    [Fact]
    public async Task GetUserDetail_ForUserWithBirthData_ShowsPlaceAndTier()
    {
        var user = await AuthedUserClientAsync("uid-admin-users-2");
        await user.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Detail Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));
        var me = await user.GetFromJsonAsync<JsonElement>("/me");
        var userId = me.GetProperty("id").GetGuid();

        var admin = await AuthedAdminClientAsync();
        var detail = await admin.GetFromJsonAsync<AdminUserDetail>($"/admin/users/{userId}");

        Assert.Equal("Mumbai, Maharashtra, India", detail!.BirthPlace);
        Assert.Equal("Free", detail.Tier);
    }

    [Fact]
    public async Task GetUserDetail_ForUnknownId_Returns404()
    {
        var admin = await AuthedAdminClientAsync();
        var response = await admin.GetAsync($"/admin/users/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    // ── Ask Jay questions ────────────────────────────────────────────────

    [Fact]
    public async Task ReplyToQuestion_PostsAstrologerMessageAndMarksAnswered()
    {
        var user = await AuthedUserClientAsync("uid-admin-q-1");
        var asked = await (await user.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Will I get promoted?", "standard")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        var admin = await AuthedAdminClientAsync();
        var detailBefore = await admin.GetFromJsonAsync<AdminQuestionDetail>($"/admin/questions/{asked!.QuestionId}");
        Assert.Equal("Pending", detailBefore!.Status);
        Assert.True(detailBefore.Context.TryGetProperty("chart", out _) || detailBefore.Context.ValueKind == JsonValueKind.Object);

        var replyResponse = await admin.PostAsJsonAsync(
            $"/admin/questions/{asked.QuestionId}/reply", new AdminReplyRequest("Here's my reading..."));
        Assert.Equal(HttpStatusCode.OK, replyResponse.StatusCode);

        var detailAfter = await admin.GetFromJsonAsync<AdminQuestionDetail>($"/admin/questions/{asked.QuestionId}");
        Assert.Equal("Answered", detailAfter!.Status);
        Assert.Contains(detailAfter.Messages, m => m.Sender == "astrologer" && m.Text == "Here's my reading...");

        // The user's own thread must show the same astrologer message.
        var userThread = await user.GetFromJsonAsync<JsonElement>($"/consult/questions/{asked.QuestionId}/messages");
        Assert.Contains(userThread.EnumerateArray(), m => m.GetProperty("sender").GetString() == "astrologer");
    }

    [Fact]
    public async Task ListQuestions_FilteredByPendingStatus_ExcludesAnswered()
    {
        var user = await AuthedUserClientAsync("uid-admin-q-2");
        var asked = await (await user.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Q1", "standard")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        var admin = await AuthedAdminClientAsync();
        await admin.PostAsJsonAsync($"/admin/questions/{asked!.QuestionId}/reply", new AdminReplyRequest("Answered."));

        var pending = await admin.GetFromJsonAsync<JsonElement>("/admin/questions?status=Pending&pageSize=100");
        Assert.DoesNotContain(pending.GetProperty("questions").EnumerateArray(),
            q => q.GetProperty("id").GetGuid() == asked.QuestionId);
    }

    [Fact]
    public async Task CloseQuestion_SetsStatusToClosed()
    {
        var user = await AuthedUserClientAsync("uid-admin-q-3");
        var asked = await (await user.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Q1", "standard")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        var admin = await AuthedAdminClientAsync();
        var response = await admin.PostAsync($"/admin/questions/{asked!.QuestionId}/close", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var detail = await admin.GetFromJsonAsync<AdminQuestionDetail>($"/admin/questions/{asked.QuestionId}");
        Assert.Equal("Closed", detail!.Status);
    }

    // The queue and its detail view should tell an astrologer/admin who's
    // asking and what they're subscribed to — a Saga+ subscriber's question
    // looks the same as anyone else's without it.
    [Fact]
    public async Task QuestionListAndDetail_ShowUserNameAndSubscriptionPlanName()
    {
        var user = await AuthedUserClientAsync("uid-admin-q-plan");
        await GrantSagaPlusAsync("uid-admin-q-plan", BillingCycle.Yearly);
        await user.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Plan Label Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));
        var asked = await (await user.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Q with a plan label", "standard")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        var admin = await AuthedAdminClientAsync();

        var list = await admin.GetFromJsonAsync<JsonElement>("/admin/questions?status=Pending&pageSize=100");
        var listEntry = list.GetProperty("questions").EnumerateArray()
            .Single(q => q.GetProperty("id").GetGuid() == asked!.QuestionId);
        Assert.Equal("Plan Label Test", listEntry.GetProperty("userName").GetString());
        Assert.Equal("Saga+ Annual", listEntry.GetProperty("subscriptionPlanName").GetString());

        var detail = await admin.GetFromJsonAsync<AdminQuestionDetail>($"/admin/questions/{asked!.QuestionId}");
        Assert.Equal("Plan Label Test", detail!.UserName);
        Assert.Equal("Saga+ Annual", detail.SubscriptionPlanName);
    }

    // ── Appointments ─────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateAppointmentStatus_ChangesItForEveryone()
    {
        var user = await AuthedUserClientAsync("uid-admin-appt-1");
        var booked = await (await user.PostAsJsonAsync("/consult/appointments", new BookAppointmentRequest(
            "Career", "test@example.com", null, new DateOnly(2026, 12, 1), new TimeOnly(10, 0))))
            .Content.ReadFromJsonAsync<BookAppointmentResponse>();

        var admin = await AuthedAdminClientAsync();
        var update = await admin.PatchAsJsonAsync(
            $"/admin/appointments/{booked!.AppointmentId}/status", new AdminUpdateAppointmentStatusRequest("Confirmed"));
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);

        var list = await admin.GetFromJsonAsync<JsonElement>("/admin/appointments?status=Confirmed&pageSize=100");
        Assert.Contains(list.GetProperty("appointments").EnumerateArray(),
            a => a.GetProperty("id").GetGuid() == booked.AppointmentId);
    }

    [Fact]
    public async Task UpdateAppointmentStatus_WithInvalidStatus_Returns400()
    {
        var user = await AuthedUserClientAsync("uid-admin-appt-2");
        var booked = await (await user.PostAsJsonAsync("/consult/appointments", new BookAppointmentRequest(
            "Career", "test@example.com", null, new DateOnly(2026, 12, 1), new TimeOnly(10, 0))))
            .Content.ReadFromJsonAsync<BookAppointmentResponse>();

        var admin = await AuthedAdminClientAsync();
        var update = await admin.PatchAsJsonAsync(
            $"/admin/appointments/{booked!.AppointmentId}/status", new AdminUpdateAppointmentStatusRequest("NotARealStatus"));
        Assert.Equal(HttpStatusCode.BadRequest, update.StatusCode);
    }

    // ── Remedies CRUD ────────────────────────────────────────────────────

    [Fact]
    public async Task CreateUpdateDeleteRemedy_RoundTripsCorrectly()
    {
        var admin = await AuthedAdminClientAsync();

        var created = await (await admin.PostAsJsonAsync("/admin/remedies",
            new AdminRemedyRequest("lifestyle", "Test Remedy", "Do a thing.", "general", null)))
            .Content.ReadFromJsonAsync<JsonElement>();
        var id = created.GetProperty("id").GetGuid();

        var updateResponse = await admin.PutAsJsonAsync($"/admin/remedies/{id}",
            new AdminRemedyRequest("mantra", "Updated Remedy", "Do a different thing.", "Saturn", "https://example.com/a.mp3"));
        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

        var list = await admin.GetFromJsonAsync<JsonElement>("/admin/remedies");
        var found = list.EnumerateArray().Single(r => r.GetProperty("id").GetGuid() == id);
        Assert.Equal("Updated Remedy", found.GetProperty("title").GetString());
        Assert.Equal("Saturn", found.GetProperty("triggerRule").GetString());

        var deleteResponse = await admin.DeleteAsync($"/admin/remedies/{id}");
        Assert.Equal(HttpStatusCode.OK, deleteResponse.StatusCode);

        var listAfter = await admin.GetFromJsonAsync<JsonElement>("/admin/remedies");
        Assert.DoesNotContain(listAfter.EnumerateArray(), r => r.GetProperty("id").GetGuid() == id);
    }

    // ── Plan pricing ─────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateConsultPlanPrice_ReflectsOnThePublicEndpointImmediately()
    {
        var admin = await AuthedAdminClientAsync();
        var update = await admin.PutAsJsonAsync("/admin/plans/consult/standard",
            new AdminUpdateConsultPlanRequest("Standard", 149, 6));
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);

        var publicClient = _factory.CreateClient();
        var plans = await publicClient.GetFromJsonAsync<JsonElement>("/consult/plans");
        var standard = plans.EnumerateArray().Single(p => p.GetProperty("id").GetString() == "standard");
        Assert.Equal(149, standard.GetProperty("priceRupees").GetInt64());
        Assert.Equal(6, standard.GetProperty("slaHours").GetInt32());
    }

    [Fact]
    public async Task UpdateSubscriptionPlan_ReflectsOnThePublicEndpointImmediately()
    {
        var admin = await AuthedAdminClientAsync();
        var update = await admin.PutAsJsonAsync("/admin/plans/subscription/saga_plus_monthly",
            new AdminUpdateSubscriptionPlanRequest("Saga+ Monthly", 349, ["New feature"]));
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);

        var publicClient = _factory.CreateClient();
        var plans = await publicClient.GetFromJsonAsync<JsonElement>("/subscription/plans");
        var monthly = plans.EnumerateArray().Single(p => p.GetProperty("id").GetString() == "saga_plus_monthly");
        Assert.Equal(349, monthly.GetProperty("priceRupees").GetInt64());
        Assert.Equal("New feature", monthly.GetProperty("features")[0].GetString());
    }

    [Fact]
    public async Task AllAdminEndpoints_WithoutAdminAuth_Return401()
    {
        var client = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/admin/users")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/admin/questions")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/admin/appointments")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/admin/remedies")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/admin/plans/consult")).StatusCode);
    }
}

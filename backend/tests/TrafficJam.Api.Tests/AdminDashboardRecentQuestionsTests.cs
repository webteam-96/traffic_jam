using System.Net.Http.Json;
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

// A dedicated fixture (rather than reusing AdminEndpointsTests) so
// /admin/dashboard/summary's Take(6)-windowed RecentQuestions list only ever
// contains the questions this test itself creates — asserting on specific
// entries in a shared-database class would be flaky if other tests' Ask Jay
// questions pushed these out of the top-6 window.
public class AdminDashboardRecentQuestionsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public AdminDashboardRecentQuestionsTests(TrafficJamApiFactory factory) => _factory = factory;

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

    // Recent questions should identify who asked and what they're subscribed
    // to, so an admin can tell a Saga+ subscriber's question from a Free
    // user's at a glance without opening the full Questions page.
    [Fact]
    public async Task RecentQuestions_IncludeUserNameAndSubscriptionPlanName()
    {
        var freeUser = await AuthedUserClientAsync("uid-dash-recent-free");
        await freeUser.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Free Asker", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));
        var freeAsk = await freeUser.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Free tier question", "standard"));
        var freeQuestionId = (await freeAsk.Content.ReadFromJsonAsync<AskQuestionResponse>())!.QuestionId;

        var monthlyUser = await AuthedUserClientAsync("uid-dash-recent-monthly");
        await GrantSagaPlusAsync("uid-dash-recent-monthly", BillingCycle.Monthly);
        await monthlyUser.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Monthly Asker", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));
        var monthlyAsk = await monthlyUser.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Saga+ Monthly question", "standard"));
        var monthlyQuestionId = (await monthlyAsk.Content.ReadFromJsonAsync<AskQuestionResponse>())!.QuestionId;

        var annualUser = await AuthedUserClientAsync("uid-dash-recent-annual");
        await GrantSagaPlusAsync("uid-dash-recent-annual", BillingCycle.Yearly);
        await annualUser.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Annual Asker", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));
        var annualAsk = await annualUser.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Saga+ Annual question", "standard"));
        var annualQuestionId = (await annualAsk.Content.ReadFromJsonAsync<AskQuestionResponse>())!.QuestionId;

        var admin = await AuthedAdminClientAsync();
        var summary = await admin.GetFromJsonAsync<AdminDashboardSummary>("/admin/dashboard/summary");

        var freeEntry = summary!.RecentQuestions.Single(q => q.Id == freeQuestionId);
        Assert.Equal("Free Asker", freeEntry.UserName);
        Assert.Equal("Free", freeEntry.SubscriptionPlanName);

        var monthlyEntry = summary.RecentQuestions.Single(q => q.Id == monthlyQuestionId);
        Assert.Equal("Monthly Asker", monthlyEntry.UserName);
        Assert.Equal("Saga+ Monthly", monthlyEntry.SubscriptionPlanName);

        var annualEntry = summary.RecentQuestions.Single(q => q.Id == annualQuestionId);
        Assert.Equal("Annual Asker", annualEntry.UserName);
        Assert.Equal("Saga+ Annual", annualEntry.SubscriptionPlanName);
    }
}

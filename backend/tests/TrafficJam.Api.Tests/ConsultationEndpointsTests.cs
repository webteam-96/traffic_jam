using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Consultation;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

public class ConsultationEndpointsTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public ConsultationEndpointsTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<HttpClient> AuthedClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session",
            new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);
        return client;
    }

    private async Task GrantSagaPlusAsync(string uid)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var userId = await db.Users.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        db.Subscriptions.Add(new Subscription { UserId = userId, Tier = SubscriptionTier.SagaPlus, RenewsAt = DateTime.UtcNow.AddDays(30) });
        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task ConsultPlans_IsPublic_NoAuthRequired()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/consult/plans");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task AskQuestion_WithUnknownPlan_Returns400()
    {
        var client = await AuthedClientAsync("uid-ask-badplan");

        var response = await client.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Will I get promoted?", "not-a-real-plan"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AskQuestion_ThenListIt_AppearsInMyQuestions()
    {
        var client = await AuthedClientAsync("uid-ask-1");

        var askResponse = await client.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Will I get promoted?", "standard"));
        Assert.Equal(HttpStatusCode.OK, askResponse.StatusCode);
        var asked = await askResponse.Content.ReadFromJsonAsync<AskQuestionResponse>();
        Assert.True(asked!.Sla > DateTime.UtcNow); // standard plan SLA is a few hours out

        var list = await client.GetFromJsonAsync<List<QuestionSummary>>("/consult/questions");
        Assert.Single(list!);
        Assert.Equal("career", list![0].Domain);
        Assert.Equal("pending", list[0].Status);
    }

    // "Priority Ask Jay" (Saga+ feature copy) — a subscriber gets the
    // fastest SLA any consult plan offers even when they pick "standard",
    // instead of needing to separately pay per-question for "priority".
    [Fact]
    public async Task AskQuestion_SagaPlusSubscriber_GetsPrioritySlaEvenOnStandardPlan()
    {
        var client = await AuthedClientAsync("uid-ask-sagaplus");
        await GrantSagaPlusAsync("uid-ask-sagaplus");

        var askResponse = await client.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Will I get promoted?", "standard"));
        var asked = await askResponse.Content.ReadFromJsonAsync<AskQuestionResponse>();

        // "standard" is a 4-hour SLA; a Saga+ subscriber should get "priority"'s 1-hour SLA instead.
        Assert.True(asked!.Sla <= DateTime.UtcNow.AddHours(1).AddMinutes(1));
    }

    [Fact]
    public async Task AskQuestion_FreeTierOnStandardPlan_KeepsTheStandardSla()
    {
        var client = await AuthedClientAsync("uid-ask-free-standard");

        var askResponse = await client.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Will I get promoted?", "standard"));
        var asked = await askResponse.Content.ReadFromJsonAsync<AskQuestionResponse>();

        Assert.True(asked!.Sla > DateTime.UtcNow.AddHours(1).AddMinutes(1)); // not silently upgraded
    }

    [Fact]
    public async Task Messages_SendThenGet_AppearsInTheThread()
    {
        var client = await AuthedClientAsync("uid-ask-msg");
        var asked = await (await client.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("love", "Is this the one?", "priority")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        var sendResponse = await client.PostAsJsonAsync(
            $"/consult/questions/{asked!.QuestionId}/messages", new SendMessageRequest("Any update?"));
        Assert.Equal(HttpStatusCode.OK, sendResponse.StatusCode);

        var thread = await client.GetFromJsonAsync<List<MessageResponse>>($"/consult/questions/{asked.QuestionId}/messages");
        Assert.Single(thread!);
        Assert.Equal("user", thread![0].Sender);
        Assert.Equal("Any update?", thread[0].Text);
    }

    [Fact]
    public async Task AskQuestion_WithoutBirthDataSaved_StoresEmptyContext()
    {
        var client = await AuthedClientAsync("uid-ask-nocontext");
        var asked = await (await client.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Will I get promoted?", "standard")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var question = await db.Questions.SingleAsync(q => q.Id == asked!.QuestionId);

        Assert.Equal("{}", question.ContextJson);
    }

    // Regression test for BACKEND_REQUIREMENTS.md's Ask Jay spec: "the backend
    // joins the user's chart + current Dasha + active transits + today's
    // Panchang into the question record before routing to an astrologer."
    [Fact]
    public async Task AskQuestion_WithBirthDataSaved_JoinsChartDashaTransitsAndPanchangIntoContext()
    {
        var client = await AuthedClientAsync("uid-ask-context");
        await client.PutAsJsonAsync("/me/birth-data", new BirthDataRequest(
            "Context Test", new DateOnly(1990, 5, 15), new TimeOnly(14, 30), false,
            "Mumbai, Maharashtra, India", 19.0760, 72.8777, "Asia/Kolkata"));

        var asked = await (await client.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Will I get promoted?", "standard")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var question = await db.Questions.SingleAsync(q => q.Id == asked!.QuestionId);
        var context = JsonSerializer.Deserialize<JsonElement>(question.ContextJson);

        var chart = context.GetProperty("chart");
        Assert.True(chart.TryGetProperty("sunSign", out _));
        Assert.True(chart.TryGetProperty("moonSign", out _));
        Assert.True(chart.TryGetProperty("nakshatra", out _));

        var dasha = context.GetProperty("dasha");
        Assert.True(dasha.TryGetProperty("maha", out var maha) && maha.GetString()!.Length > 0);
        Assert.True(dasha.TryGetProperty("antar", out _));

        var panchang = context.GetProperty("panchang");
        Assert.True(panchang.TryGetProperty("tithi", out _));
        Assert.True(panchang.TryGetProperty("nakshatra", out _));

        var transits = context.GetProperty("transits");
        Assert.True(transits.GetArrayLength() > 0);
        var firstTransit = transits.EnumerateArray().First();
        Assert.True(firstTransit.TryGetProperty("planet", out _));
        Assert.True(firstTransit.TryGetProperty("houseFromMoon", out _));
    }

    [Fact]
    public async Task Messages_ForAnotherUsersQuestion_Returns404()
    {
        var owner = await AuthedClientAsync("uid-ask-owner");
        var asked = await (await owner.PostAsJsonAsync("/consult/questions",
            new AskQuestionRequest("career", "Owner's question", "standard")))
            .Content.ReadFromJsonAsync<AskQuestionResponse>();

        var attacker = await AuthedClientAsync("uid-ask-attacker");
        var response = await attacker.GetAsync($"/consult/questions/{asked!.QuestionId}/messages");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task BookAppointment_ReturnsAReferenceAndPersistsAsPending()
    {
        var client = await AuthedClientAsync("uid-appt-1");

        var response = await client.PostAsJsonAsync("/consult/appointments", new BookAppointmentRequest(
            "Career", "test@example.com", "Career guidance please",
            new DateOnly(2026, 12, 1), new TimeOnly(10, 0)));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var booked = await response.Content.ReadFromJsonAsync<BookAppointmentResponse>();

        Assert.StartsWith("TJ-", booked!.Reference);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var appointment = await db.Appointments.SingleAsync(a => a.Id == booked.AppointmentId);
        Assert.Equal("Career", appointment.Area);
        Assert.Equal(AppointmentStatus.Pending, appointment.Status);
    }

    [Fact]
    public async Task BookAppointment_WithoutAuth_Returns401()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/consult/appointments", new BookAppointmentRequest(
            "Career", "test@example.com", null, new DateOnly(2026, 12, 1), new TimeOnly(10, 0)));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Subscription_ForNewUser_DefaultsToFreeTier()
    {
        var client = await AuthedClientAsync("uid-sub-1");

        var sub = await client.GetFromJsonAsync<SubscriptionResponse>("/subscription");

        Assert.Equal("Free", sub!.Tier);
    }

    [Fact]
    public async Task SubscriptionPlans_IsPublic()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/subscription/plans");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Checkout_WithoutPaymentGatewayConfigured_ReturnsCleanServiceUnavailable()
    {
        var client = await AuthedClientAsync("uid-checkout-1");

        var response = await client.PostAsJsonAsync("/subscription/checkout", new CheckoutRequest("saga_plus_monthly"));

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task Verify_WithoutPaymentGatewayConfigured_ReturnsCleanServiceUnavailable()
    {
        var client = await AuthedClientAsync("uid-verify-1");

        var response = await client.PostAsJsonAsync("/subscription/verify",
            new VerifyRequest("order-1", "pay-1", "sig-1", "saga_plus_monthly"));

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }
}

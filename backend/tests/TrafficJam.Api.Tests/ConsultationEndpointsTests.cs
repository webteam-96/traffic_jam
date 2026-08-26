using System.Net;
using System.Net.Http.Json;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Consultation;
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

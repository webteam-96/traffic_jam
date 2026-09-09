using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Notifications;
using TrafficJam.Api.Modules.Users;
using Xunit;

namespace TrafficJam.Api.Tests;

/// <summary>
/// The inbox used to be permanently empty: the entity, the endpoints, the
/// preferences screen and the filter all existed, and nothing ever wrote a
/// row. These cover the half that was missing — and, more importantly, that
/// preferences actually gate it rather than decorating a screen.
/// </summary>
public class NotificationGeneratorTests : IClassFixture<TrafficJamApiFactory>, IAsyncLifetime
{
    private readonly TrafficJamApiFactory _factory;

    public NotificationGeneratorTests(TrafficJamApiFactory factory) => _factory = factory;

    public Task InitializeAsync() => _factory.ResetDatabaseAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private async Task<(HttpClient client, Guid userId)> AuthedClientAsync(string uid)
    {
        var client = _factory.CreateClient();
        var session = await client.PostAsJsonAsync("/auth/session",
            new SessionRequest($"{uid}:+91{uid.GetHashCode() & 0x7FFFFFFF}"));
        var tokens = await session.Content.ReadFromJsonAsync<SessionResponse>();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", tokens!.AccessToken);

        var me = await client.GetFromJsonAsync<MeResponse>("/me");
        return (client, me!.Id);
    }

    private static async Task SaveBirthDataAsync(HttpClient client) =>
        await client.PutAsJsonAsync("/me/birth-data", new
        {
            name = "Test User",
            dob = "1988-10-24",
            tob = "10:12:00",
            unknownTime = false,
            place = "Mumbai, Maharashtra, India",
            lat = 19.0760,
            lng = 72.8777,
            timezone = "Asia/Kolkata",
        });

    private static async Task SetPrefsAsync(HttpClient client, bool morning, bool rahuKaal, bool dasha, bool chat) =>
        await client.PutAsJsonAsync("/me/notification-preferences",
            new NotificationPreferencesRequest(
                Morning: morning, RahuKaal: rahuKaal, Events: false, Dasha: dasha,
                Remedies: false, Chat: chat,
                Channels: new Dictionary<string, string[]>()));

    private async Task<List<NotificationResponse>> InboxAsync(HttpClient client) =>
        (await client.GetFromJsonAsync<List<NotificationResponse>>("/notifications"))!;

    // The headline behaviour: an inbox that fills itself.
    [Fact]
    public async Task Get_WithBirthDataSaved_ProducesNotificationsInsteadOfAnEmptyInbox()
    {
        var (client, _) = await AuthedClientAsync("uid-gen-1");
        await SaveBirthDataAsync(client);

        var inbox = await InboxAsync(client);

        Assert.NotEmpty(inbox);
        Assert.Contains(inbox, n => n.Type.StartsWith("morning:"));
        Assert.Contains(inbox, n => n.Type.StartsWith("rahukaal:"));
    }

    // A category switched off produces nothing at all — it isn't generated and
    // then filtered out of the view, which would still leave it in the table.
    [Fact]
    public async Task Get_WithACategoryDisabled_ProducesNothingForThatCategory()
    {
        var (client, _) = await AuthedClientAsync("uid-gen-2");
        await SaveBirthDataAsync(client);
        await SetPrefsAsync(client, morning: false, rahuKaal: true, dasha: false, chat: false);

        var inbox = await InboxAsync(client);

        Assert.DoesNotContain(inbox, n => n.Type.StartsWith("morning:"));
        Assert.Contains(inbox, n => n.Type.StartsWith("rahukaal:"));
    }

    // The case in the request: only one category on means only that category
    // arrives.
    [Fact]
    public async Task Get_WithOnlyOneCategoryEnabled_ProducesOnlyThatCategory()
    {
        var (client, _) = await AuthedClientAsync("uid-gen-3");
        await SaveBirthDataAsync(client);
        await SetPrefsAsync(client, morning: true, rahuKaal: false, dasha: false, chat: false);

        var inbox = await InboxAsync(client);

        Assert.All(inbox, n => Assert.StartsWith("morning:", n.Type));
        Assert.Single(inbox);
    }

    [Fact]
    public async Task Get_WithEverythingDisabled_LeavesTheInboxEmpty()
    {
        var (client, _) = await AuthedClientAsync("uid-gen-4");
        await SaveBirthDataAsync(client);
        await SetPrefsAsync(client, morning: false, rahuKaal: false, dasha: false, chat: false);

        Assert.Empty(await InboxAsync(client));
    }

    // Generation runs on every read, so it has to be idempotent or the inbox
    // would grow by a full day's worth of duplicates each time it was opened.
    [Fact]
    public async Task Get_CalledRepeatedly_DoesNotDuplicate()
    {
        var (client, _) = await AuthedClientAsync("uid-gen-5");
        await SaveBirthDataAsync(client);

        var first = await InboxAsync(client);
        await InboxAsync(client);
        var third = await InboxAsync(client);

        Assert.Equal(first.Count, third.Count);
        Assert.Equal(third.Select(n => n.Type).Distinct().Count(), third.Count);
    }

    // Without birth data there is no Panchang to report, and the generator
    // must skip those categories rather than throw and take the inbox with it.
    [Fact]
    public async Task Get_WithNoBirthData_ReturnsEmptyRatherThanFailing()
    {
        var (client, _) = await AuthedClientAsync("uid-gen-6");

        Assert.Empty(await InboxAsync(client));
    }

    // An astrologer reply is the one category that isn't daily — it keys on
    // the message, so each answer notifies once and a conversation doesn't
    // re-notify for older replies.
    [Fact]
    public async Task Get_AfterAnAstrologerReplies_ProducesOneNotificationPerReply()
    {
        var (client, userId) = await AuthedClientAsync("uid-gen-7");
        await SaveBirthDataAsync(client);

        Guid questionId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var question = new Question
            {
                UserId = userId, Domain = "Career", Text = "When should I switch jobs?",
                ContextJson = "{}", Plan = "standard", SlaAt = DateTime.UtcNow.AddHours(4),
            };
            db.Questions.Add(question);
            db.Messages.Add(new Message
            {
                QuestionId = question.Id, Sender = MessageSender.Astrologer,
                Text = "Wait until your Jupiter period begins.",
            });
            await db.SaveChangesAsync();
            questionId = question.Id;
        }

        var inbox = await InboxAsync(client);

        var chat = inbox.Where(n => n.Type.StartsWith("chat:")).ToList();
        Assert.Single(chat);
        // The key carries the question id so the app can open that thread.
        Assert.StartsWith($"chat:{questionId}:", chat[0].Type);
        Assert.Equal("Jay has replied", chat[0].Title);
        Assert.Contains("Jupiter", chat[0].Body);
        Assert.NotEqual(Guid.Empty, questionId);
    }

    [Fact]
    public async Task Get_WithChatDisabled_DoesNotNotifyAboutReplies()
    {
        var (client, userId) = await AuthedClientAsync("uid-gen-8");
        await SaveBirthDataAsync(client);
        await SetPrefsAsync(client, morning: false, rahuKaal: false, dasha: false, chat: false);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var question = new Question
            {
                UserId = userId, Domain = "Career", Text = "Anything?",
                ContextJson = "{}", Plan = "standard", SlaAt = DateTime.UtcNow.AddHours(4),
            };
            db.Questions.Add(question);
            db.Messages.Add(new Message
            {
                QuestionId = question.Id, Sender = MessageSender.Astrologer, Text = "A reply.",
            });
            await db.SaveChangesAsync();
        }

        Assert.DoesNotContain(await InboxAsync(client), n => n.Type.StartsWith("chat:"));
    }

    // One user's replies must never reach another's inbox.
    [Fact]
    public async Task Get_DoesNotLeakAnotherUsersAstrologerReplies()
    {
        var (mine, _) = await AuthedClientAsync("uid-gen-9");
        var (_, theirUserId) = await AuthedClientAsync("uid-gen-10");
        await SaveBirthDataAsync(mine);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var question = new Question
            {
                UserId = theirUserId, Domain = "Career", Text = "Theirs",
                ContextJson = "{}", Plan = "standard", SlaAt = DateTime.UtcNow.AddHours(4),
            };
            db.Questions.Add(question);
            db.Messages.Add(new Message
            {
                QuestionId = question.Id, Sender = MessageSender.Astrologer, Text = "Their answer.",
            });
            await db.SaveChangesAsync();
        }

        Assert.DoesNotContain(await InboxAsync(mine), n => n.Type.StartsWith("chat:"));
    }
}

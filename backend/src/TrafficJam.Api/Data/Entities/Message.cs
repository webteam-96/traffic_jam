namespace TrafficJam.Api.Data.Entities;

public enum MessageSender
{
    User,
    Astrologer,
}

public class Message
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid QuestionId { get; set; }
    public required MessageSender Sender { get; set; }
    public required string Text { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Question Question { get; set; } = null!;
}

namespace TrafficJam.Api.Data.Entities;

public enum QuestionStatus
{
    Pending,
    Answered,
    Closed,
}

public class Question
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string Domain { get; set; }
    public required string Text { get; set; }

    /// <summary>Snapshot of chart + Dasha + active transits + today's Panchang at submission time.</summary>
    public required string ContextJson { get; set; }

    public required string Plan { get; set; }
    public QuestionStatus Status { get; set; } = QuestionStatus.Pending;

    /// <summary>SLA deadline — 2-4h standard, 30min premium.</summary>
    public required DateTime SlaAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
    public ICollection<Message> Messages { get; set; } = [];
}

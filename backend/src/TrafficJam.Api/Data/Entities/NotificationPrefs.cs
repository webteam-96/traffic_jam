namespace TrafficJam.Api.Data.Entities;

public class NotificationPrefs
{
    public Guid UserId { get; set; }
    public bool Morning { get; set; } = true;
    public bool RahuKaal { get; set; } = true;
    public bool Events { get; set; }
    public bool Dasha { get; set; } = true;
    public bool Remedies { get; set; }

    /// <summary>Jay (or a panel astrologer) replying to a question. On by
    /// default: a reply is a direct answer to something the user asked, so
    /// silence would look like being ignored.</summary>
    public bool Chat { get; set; } = true;

    /// <summary>Comma-separated channels per category (push/email/whatsapp) — kept simple as a JSON blob; the app already models per-category channel sets.</summary>
    public string ChannelsJson { get; set; } = "{}";

    public User User { get; set; } = null!;
}

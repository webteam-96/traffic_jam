namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// Jay's profile, as shown on the app's About screen. A single row — the app
/// has one astrologer — so it carries a fixed [SingletonId] rather than being
/// looked up by anything.
///
/// Everything here used to be hardcoded in about_jay_kotecha_screen.dart, so
/// changing a line of Jay's biography meant a new app release. This is the
/// same move RemedyContent made: content the team owns lives in the database,
/// not in the binary.
/// </summary>
public class AstrologerProfile
{
    /// <summary>The one row. Fixed so the admin panel and the app can both
    /// address it without a lookup, and so a second profile can't appear.</summary>
    public static readonly Guid SingletonId = new("a57e10c9-0000-4000-8000-000000000001");

    public Guid Id { get; set; } = SingletonId;

    public required string Name { get; set; }
    public required string Title { get; set; }

    /// <summary>Biography, one paragraph per line. Kept as free text rather
    /// than structured paragraphs so the admin can add or remove one without
    /// a schema change.</summary>
    public required string Bio { get; set; }

    /// <summary>The pull-quote shown under "Philosophy &amp; Approach".</summary>
    public required string Philosophy { get; set; }

    /// <summary>Areas of expertise, one per line — rendered as chips.</summary>
    public required string Expertise { get; set; }

    /// <summary>
    /// Profile photo as a data URI (e.g. "data:image/jpeg;base64,...").
    /// Stored inline rather than as a file URL because this project has no
    /// object storage and no static-file host; a profile photo is small
    /// enough that a LONGTEXT column is a fair trade for not standing up
    /// infrastructure. Null falls back to the bundled avatar asset.
    /// </summary>
    public string? ImageDataUri { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public enum ReviewStatus
{
    /// <summary>Submitted by a user, awaiting moderation. Never shown in the app.</summary>
    Pending,
    Approved,
    Rejected,
}

/// <summary>
/// One client testimonial on the About screen.
///
/// Two ways one gets here: the team writes it in the admin panel (UserId null,
/// approved on creation), or a user submits it from the app (UserId set,
/// Pending until someone approves it). Only Approved rows ever reach the app,
/// which is why the moderation state lives on the row rather than in a
/// separate queue table — there is no way to read a review without also
/// reading whether it may be shown.
/// </summary>
public class AstrologerReview
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Quote { get; set; }

    /// <summary>Attribution as displayed, e.g. "Rohan M., Software Architect".</summary>
    public required string Author { get; set; }

    /// <summary>Lower sorts first, so the admin can order them deliberately
    /// rather than being stuck with insertion order.</summary>
    public int SortOrder { get; set; }

    /// <summary>Who submitted it. Null means the team wrote it themselves.</summary>
    public Guid? UserId { get; set; }

    /// <summary>Defaults to Pending so a row can never be published by
    /// accident — the admin path sets Approved explicitly.</summary>
    public ReviewStatus Status { get; set; } = ReviewStatus.Pending;

    /// <summary>Star rating out of 5, as submitted. Null for admin-authored
    /// testimonials, which carry no rating.</summary>
    public int? Rating { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ModeratedAt { get; set; }

    public User? User { get; set; }
}

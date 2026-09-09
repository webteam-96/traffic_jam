using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Astrologer;

/// <summary>
/// The About screen's original hardcoded copy, moved into the database
/// verbatim. Seeding it rather than starting empty means the screen looks the
/// same the moment it switches from hardcoded text to a fetch — nobody has to
/// open the admin panel first to stop it being blank.
/// </summary>
public static class AstrologerSeedData
{
    public static readonly AstrologerProfile Profile = new()
    {
        Id = AstrologerProfile.SingletonId,
        Name = "Jay Kotecha",
        Title = "Founder & Chief Astrologer",
        Bio = string.Join('\n',
            "Jay Kotecha is a practicing Vedic astrologer with over 18 years of experience "
            + "guiding individuals and businesses through life's critical intersections. "
            + "Trained in the traditional guru-shishya parampara under the lineage of "
            + "Pt. Sanjay Rath, he holds advanced certifications in Jaimini Sutras, "
            + "Prashna (horary), and KP (Krishnamurti Paddhati) systems.",
            "Before dedicating himself fully to Jyotish, Jay spent a decade in corporate "
            + "finance and strategy consulting — an experience that grounds his readings in "
            + "practical decision-making rather than abstract prediction. He has served clients "
            + "across 22 countries and is a regular contributor to leading wellness platforms.",
            "Jay founded TrafficJam.Life to democratize access to authentic, "
            + "birth-chart-level guidance — moving astrology from entertainment to a daily "
            + "decision engine for the modern seeker."),
        Philosophy = "Astrology is a compass, not a verdict. The planets show the weather; "
            + "you choose the path. My role is to read the sky clearly so you can walk "
            + "with confidence — whether the signal is green, yellow, or red.",
        Expertise = string.Join('\n',
            "Vedic Astrology (Parashara)",
            "KP System (Krishnamurti Paddhati)",
            "Prashna / Horary Astrology",
            "Remedial Astrology (Mantra, Yantra, Dana)",
            "Financial & Business Astrology",
            "Relationship & Compatibility Analysis",
            "Muhurat / Electional Astrology",
            "Nakshatra & Dasha Deep-Dives"),
        UpdatedAt = new DateTime(2026, 9, 9, 0, 0, 0, DateTimeKind.Utc),
    };

    public static readonly AstrologerReview[] Reviews =
    [
        new()
        {
            Id = new Guid("a57e10c9-0000-4000-8000-000000000101"),
            Quote = "Jay's reading on my Saturn return timing was uncannily precise. "
                + "He identified the exact month my career would pivot — and it did.",
            Author = "Rohan M., Software Architect",
            SortOrder = 0,
            Status = ReviewStatus.Approved,
            CreatedAt = new DateTime(2026, 9, 9, 0, 0, 0, DateTimeKind.Utc),
        },
        new()
        {
            Id = new Guid("a57e10c9-0000-4000-8000-000000000102"),
            Quote = "The remedy suggestions were practical, not ritualistic. Drinking water "
                + "from a copper vessel during my Mars transit genuinely shifted my energy.",
            Author = "Anjali S., Entrepreneur",
            SortOrder = 1,
            Status = ReviewStatus.Approved,
            CreatedAt = new DateTime(2026, 9, 9, 0, 0, 0, DateTimeKind.Utc),
        },
        new()
        {
            Id = new Guid("a57e10c9-0000-4000-8000-000000000103"),
            Quote = "Business Muhurat for our Series A close — we timed the term sheet "
                + "signing to Abhijit Muhurat. Round oversubscribed in 48 hours.",
            Author = "Vikram P., Founder",
            SortOrder = 2,
            Status = ReviewStatus.Approved,
            CreatedAt = new DateTime(2026, 9, 9, 0, 0, 0, DateTimeKind.Utc),
        },
    ];
}

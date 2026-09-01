using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Remedies;

/// <summary>
/// Standard, textbook Parashari remedy practices — mantras, charity and
/// lifestyle habits, the same category of content summarized in Cosmic
/// Foundations. Deliberately excludes gemstone and medical prescriptions,
/// which need a professional's judgment about an individual chart, not a
/// static seed. <see cref="RemedyContent.TriggerRule"/> is the planet name
/// this remedy addresses (matching a Dasha lord string, e.g. "Saturn"), or
/// "general" for one that applies to everyone regardless of chart.
/// </summary>
public static class RemedySeedData
{
    public static readonly RemedyContent[] All =
    [
        new()
        {
            Id = Guid.Parse("4fdf37fa-09d9-498b-9e4c-5a0779a374fb"), Type = "lifestyle",
            Title = "Start the day before the phone does",
            Detail = "Begin each day with a few quiet minutes of reflection or meditation before checking your phone.",
            TriggerRule = "general",
        },
        new()
        {
            Id = Guid.Parse("fa9359ab-7970-466b-a528-713dc3863f3f"), Type = "lifestyle",
            Title = "Keep a gratitude journal",
            Detail = "Noting three things you're grateful for each day steadies the mind regardless of which planet is active. "
                + "These are general, traditional practices — for anything specific to your own chart, ask Jay.",
            TriggerRule = "general",
        },
        new()
        {
            Id = Guid.Parse("dc9edf2b-75ed-430d-b513-45fc88aa532b"), Type = "mantra",
            Title = "Surya mantra at sunrise",
            Detail = "Chant \"Om Suryaya Namah\" 108 times facing east at sunrise, and offer water (Arghya) to the rising sun.",
            TriggerRule = "Sun",
        },
        new()
        {
            Id = Guid.Parse("6ee467c9-cd22-4702-b341-8ac21926a9dc"), Type = "charity",
            Title = "Sunday giving",
            Detail = "Donate wheat or jaggery on Sundays — Surya's day rewards discipline, vitality and giving back.",
            TriggerRule = "Sun",
        },
        new()
        {
            Id = Guid.Parse("afaf592c-af6e-4613-8f02-a2a4ef461285"), Type = "mantra",
            Title = "Chandra mantra on Monday",
            Detail = "Chant \"Om Chandraya Namah\" on Monday evenings to steady the mind and emotions.",
            TriggerRule = "Moon",
        },
        new()
        {
            Id = Guid.Parse("064bc2b6-c738-4fd3-8b69-18d54bb4a343"), Type = "lifestyle",
            Title = "Protect your sleep around the full and new moon",
            Detail = "Keep a regular sleep schedule near the full and new moon, and donate rice or milk on Mondays.",
            TriggerRule = "Moon",
        },
        new()
        {
            Id = Guid.Parse("2ba89fb9-13c2-4247-9999-6ac7ebe613e5"), Type = "mantra",
            Title = "Mangal mantra on Tuesday",
            Detail = "Chant \"Om Angarakaya Namah\" 108 times on Tuesdays to channel Mars' energy constructively.",
            TriggerRule = "Mars",
        },
        new()
        {
            Id = Guid.Parse("833d0c04-19fa-462a-8e61-fff2aca3a27f"), Type = "charity",
            Title = "Tuesday giving, and a calmer temper",
            Detail = "Donate red lentils (masoor dal) or jaggery on Tuesdays, and avoid starting conflicts on this day.",
            TriggerRule = "Mars",
        },
        new()
        {
            Id = Guid.Parse("01a9d48d-f672-4f1b-bf28-85f904be726e"), Type = "mantra",
            Title = "Budha mantra on Wednesday",
            Detail = "Chant \"Om Budhaya Namah\" on Wednesdays to support clear thinking and communication.",
            TriggerRule = "Mercury",
        },
        new()
        {
            Id = Guid.Parse("12a6bc09-182f-4b55-85b2-045cb2f82816"), Type = "charity",
            Title = "Wednesday giving",
            Detail = "Donate green moong dal or books on Wednesdays, and feed green vegetables to cows if you can.",
            TriggerRule = "Mercury",
        },
        new()
        {
            Id = Guid.Parse("ea045864-241c-4b73-87d5-c7e9d9a3d4d7"), Type = "mantra",
            Title = "Guru mantra on Thursday",
            Detail = "Chant \"Om Gram Grim Graum Sah Gurave Namah\" on Thursdays to invite Jupiter's wisdom and growth.",
            TriggerRule = "Jupiter",
        },
        new()
        {
            Id = Guid.Parse("acbd1d3f-e302-46b9-b46b-6c4858e1eca2"), Type = "charity",
            Title = "Thursday giving",
            Detail = "Donate turmeric, chana dal, or yellow items to teachers or those in need on Thursdays.",
            TriggerRule = "Jupiter",
        },
        new()
        {
            Id = Guid.Parse("69ce6858-5b47-4fe0-a38e-3d457c1787d3"), Type = "mantra",
            Title = "Shukra mantra on Friday",
            Detail = "Chant \"Om Shukraya Namah\" on Fridays to support love, beauty and harmony.",
            TriggerRule = "Venus",
        },
        new()
        {
            Id = Guid.Parse("16e4c981-c631-4bad-acc4-6dee8a6c5e3b"), Type = "lifestyle",
            Title = "A little more beauty on Friday",
            Detail = "Donate white items (rice, sugar, clothing) on Fridays, and keep your living space clean and pleasant.",
            TriggerRule = "Venus",
        },
        new()
        {
            Id = Guid.Parse("99fba551-965e-4d17-ad79-7c8f36ace740"), Type = "mantra",
            Title = "Shani mantra on Saturday",
            Detail = "Chant \"Om Sham Shanicharaya Namah\" on Saturdays — Saturn rewards patience, discipline and humility.",
            TriggerRule = "Saturn",
        },
        new()
        {
            Id = Guid.Parse("17e0d927-0c28-467f-8514-31b1994e77fc"), Type = "charity",
            Title = "Saturday service",
            Detail = "Donate mustard oil or black sesame seeds, or spend some time serving others on Saturdays.",
            TriggerRule = "Saturn",
        },
        new()
        {
            Id = Guid.Parse("0dc6a08b-c4e6-4c8e-824a-d32be7240095"), Type = "mantra",
            Title = "Rahu mantra on Saturday",
            Detail = "Chant \"Om Rahave Namah\" on Saturdays, and avoid major decisions during Rahu Kaal.",
            TriggerRule = "Rahu",
        },
        new()
        {
            Id = Guid.Parse("21091c89-b8e0-443e-9e2b-5a416a70e3dd"), Type = "charity",
            Title = "Grounding Rahu's restlessness",
            Detail = "Donate blankets or dark-coloured grains to those in need — a grounding counterweight to Rahu's ambition.",
            TriggerRule = "Rahu",
        },
        new()
        {
            Id = Guid.Parse("6d37ff62-789f-4468-8f11-a944da36c44b"), Type = "mantra",
            Title = "Ketu mantra",
            Detail = "Chant \"Om Ketave Namah\", or a Ganesha mantra — classically believed to pacify Ketu's influence.",
            TriggerRule = "Ketu",
        },
        new()
        {
            Id = Guid.Parse("32a7bbda-6a38-4e8d-9c43-249029eab11c"), Type = "lifestyle",
            Title = "Quiet time for Ketu",
            Detail = "Set aside time for meditation or spiritual study, and consider giving anonymously when you can.",
            TriggerRule = "Ketu",
        },
    ];
}

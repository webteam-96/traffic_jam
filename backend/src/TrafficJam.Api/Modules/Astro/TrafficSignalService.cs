namespace TrafficJam.Api.Modules.Astro;

public record SignalFactor(int Score, string Driver);
public record SignalBreakdown(SignalFactor MoonTransit, SignalFactor Panchang, SignalFactor Dasha, SignalFactor Transits);
public record SignalResult(int Score, string Band, string Label, string Guidance, SignalBreakdown Breakdown);

public interface ITrafficSignalService
{
    /// <summary>
    /// Scores a day from already-computed astrological facts — this is a
    /// pure function, deliberately with no Astronomy Engine or database
    /// dependency of its own, so the scoring logic can be tested in
    /// isolation from the (already independently tested) services that
    /// produce these inputs: AstroEngineService (moon sign), PanchangService
    /// (tithi/yoga/karana), DashaService (maha/antar lords), TransitService
    /// (house-from-moon for the Moon itself and the 4 major grahas).
    /// </summary>
    SignalResult Score(
        int moonHouseFromMoon,
        int tithiIndex, int yogaIndex, string karanaName,
        string mahaLord, string antarLord,
        int jupiterHouseFromMoon, int saturnHouseFromMoon, int rahuHouseFromMoon, int ketuHouseFromMoon);
}

/// <summary>
/// Traffic Signal score — BACKEND_REQUIREMENTS.md's weighted composite:
/// Moon transit 30% + Panchang 25% + Dasha 25% + major transits 20% ->
/// Green 70-100 / Yellow 40-69 / Red 0-39. Not a new astronomical
/// calculation — a synthesis of the four pieces already built (birth chart,
/// Panchang, Dasha, transits), each turned into a 0-100 sub-score via the
/// classical lookup tables in TrafficSignalTables.cs. Unlike Tithi/Dasha/
/// Panchang math, which have one unambiguous classical definition, *how*
/// four auspiciousness signals combine into a single percentage has no one
/// canonical answer — the weights are documented and followed exactly; the
/// specific point values within each factor are this implementation's own
/// first-pass design, clearly separated from the sourced classical
/// categories in TrafficSignalTables.cs's doc comments.
/// </summary>
public class TrafficSignalService : ITrafficSignalService
{
    public SignalResult Score(
        int moonHouseFromMoon,
        int tithiIndex, int yogaIndex, string karanaName,
        string mahaLord, string antarLord,
        int jupiterHouseFromMoon, int saturnHouseFromMoon, int rahuHouseFromMoon, int ketuHouseFromMoon)
    {
        var moonScore = TrafficSignalTables.ChandraBalaScore(moonHouseFromMoon);
        var moonFactor = new SignalFactor(moonScore, MoonDriver(moonHouseFromMoon));

        var tithiScore = TrafficSignalTables.TithiTypeScore(tithiIndex);
        var yogaScore = TrafficSignalTables.YogaScore(yogaIndex);
        var karanaScore = TrafficSignalTables.KaranaScore(karanaName);
        var panchangScore = (int)Math.Round(tithiScore * 0.40 + yogaScore * 0.35 + karanaScore * 0.25);
        var panchangFactor = new SignalFactor(panchangScore, PanchangDriver(tithiScore, yogaScore, karanaScore));

        var dashaScore = TrafficSignalTables.DashaRelationshipScore(mahaLord, antarLord);
        var dashaFactor = new SignalFactor(dashaScore, DashaDriver(mahaLord, antarLord, dashaScore));

        var jupiterScore = TrafficSignalTables.JupiterTransitScore(jupiterHouseFromMoon);
        var saturnScore = TrafficSignalTables.SaturnTransitScore(saturnHouseFromMoon);
        var rahuScore = TrafficSignalTables.NodeTransitScore(rahuHouseFromMoon);
        var ketuScore = TrafficSignalTables.NodeTransitScore(ketuHouseFromMoon);
        var transitsScore = (int)Math.Round((jupiterScore + saturnScore + rahuScore + ketuScore) / 4.0);
        var transitsFactor = new SignalFactor(transitsScore, TransitsDriver(saturnHouseFromMoon, jupiterScore, saturnScore));

        var totalScore = (int)Math.Round(
            moonScore * 0.30 + panchangScore * 0.25 + dashaScore * 0.25 + transitsScore * 0.20);
        totalScore = Math.Clamp(totalScore, 0, 100);

        var band = BandForScore(totalScore);
        var (label, guidance) = LabelAndGuidance(band);

        return new SignalResult(totalScore, band, label, guidance,
            new SignalBreakdown(moonFactor, panchangFactor, dashaFactor, transitsFactor));
    }

    public static string BandForScore(int score) => score switch
    {
        >= 70 => "green",
        >= 40 => "yellow",
        _ => "red",
    };

    /// <summary>Pure function of band alone — shared so a cache-hit path (which only
    /// stores score/band/breakdown) can reconstruct the same label/guidance text
    /// this method produces on a fresh computation, without duplicating the copy.</summary>
    public static (string Label, string Guidance) LabelAndGuidance(string band) => band switch
    {
        "green" => ("Go Ahead", "The day's factors line up in your favour — a good window to move on things that matter."),
        "yellow" => ("Proceed With Care", "A mixed day. Fine for routine matters, but weigh anything major carefully."),
        _ => ("Hold Back", "Several factors are working against you today — favour caution over new commitments where you can."),
    };

    private static string MoonDriver(int house) => house switch
    {
        8 => "Moon transits your 8th house from natal Moon (Chandrashtama) — the month's most challenging Moon day.",
        1 or 3 or 6 or 7 or 10 or 11 => $"Moon favorably placed in house {house} from your natal Moon.",
        _ => $"Moon in house {house} from your natal Moon — a quieter day for the Moon.",
    };

    private static string PanchangDriver(int tithiScore, int yogaScore, int karanaScore) =>
        (tithiScore, yogaScore, karanaScore) switch
        {
            ( >= 80, >= 80, >= 70) => "Today's Tithi, Yoga, and Karana are all classically favorable.",
            (30, _, _) => "Today falls on a Rikta Tithi — classically better for routine matters than new beginnings.",
            (_, <= 35, _) => "Today's Yoga carries a classical caution against starting new ventures.",
            (_, _, 20) => "Today's Karana (Vishti) is classically considered inauspicious for new undertakings.",
            _ => "A mixed Panchang today — some elements favorable, others neutral.",
        };

    private static string DashaDriver(string mahaLord, string antarLord, int score) =>
        mahaLord == antarLord
            ? $"You're in {mahaLord}'s own Antardasha within its Mahadasha — a stable, self-consistent period."
            : score switch
            {
                85 => $"{antarLord} is a natural friend of your current {mahaLord} Mahadasha — a supportive combination.",
                25 => $"{antarLord} is a natural enemy of your current {mahaLord} Mahadasha — a more effortful combination.",
                _ => $"{antarLord} is neutral to your current {mahaLord} Mahadasha.",
            };

    private static string TransitsDriver(int saturnHouseFromMoon, int jupiterScore, int saturnScore) =>
        saturnHouseFromMoon is 12 or 1 or 2
            ? "You're in a Sade Sati window (Saturn transiting 12th/1st/2nd from your Moon) — a demanding long-term cycle."
            : jupiterScore >= 80 && saturnScore >= 80
                ? "Both Jupiter and Saturn are transiting favorably from your Moon right now."
                : "A mixed picture from the major slow-moving transits (Jupiter, Saturn, Rahu, Ketu).";
}

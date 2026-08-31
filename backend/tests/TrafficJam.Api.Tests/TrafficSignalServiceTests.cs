using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class TrafficSignalServiceTests
{
    private readonly TrafficSignalService _service = new();

    // Best-case inputs on every factor should land comfortably in Green.
    [Fact]
    public void Score_AllFactorsFavorable_LandsInGreen()
    {
        var result = _service.Score(
            moonHouseFromMoon: 1,               // Chandra Bala: favorable
            tithiIndex: 0, yogaIndex: 1, karanaName: "Bava", // Nanda tithi, auspicious yoga, non-Vishti karana
            mahaLord: "Jupiter", antarLord: "Sun",           // friends (Jupiter's friends include Sun)
            jupiterHouseFromMoon: 11, saturnHouseFromMoon: 11, rahuHouseFromMoon: 11, ketuHouseFromMoon: 11);

        Assert.Equal("green", result.Band);
        Assert.True(result.Score >= 70);
    }

    // Worst-case inputs on every factor should land in Red.
    [Fact]
    public void Score_AllFactorsUnfavorable_LandsInRed()
    {
        var result = _service.Score(
            moonHouseFromMoon: 8,                // Chandrashtama
            tithiIndex: 3, yogaIndex: 16, karanaName: "Vishti", // Rikta tithi, Vyatipata (severe), Vishti karana
            mahaLord: "Saturn", antarLord: "Sun",              // Saturn's enemies include Sun
            jupiterHouseFromMoon: 8, saturnHouseFromMoon: 1, rahuHouseFromMoon: 1, ketuHouseFromMoon: 1);

        Assert.Equal("red", result.Band);
        Assert.True(result.Score < 40);
    }

    [Theory]
    [InlineData(70, "green")]
    [InlineData(69, "yellow")]
    [InlineData(40, "yellow")]
    [InlineData(39, "red")]
    [InlineData(0, "red")]
    [InlineData(100, "green")]
    public void BandForScore_MatchesDocumentedThresholds(int score, string expectedBand)
    {
        Assert.Equal(expectedBand, TrafficSignalService.BandForScore(score));
    }

    [Fact]
    public void Score_MatchesTheDocumentedWeightedFormulaExactly()
    {
        // Pick inputs whose sub-scores are all independently known, then
        // verify the total is exactly 0.30*moon + 0.25*panchang + 0.25*dasha
        // + 0.20*transits — the documented BACKEND_REQUIREMENTS.md formula,
        // not just "a plausible-looking number."
        var moonHouseFromMoon = 1;      // ChandraBalaScore -> 90
        var tithiIndex = 0;             // TithiTypeScore -> 90
        var yogaIndex = 1;              // YogaScore (Priti, not in either inauspicious set) -> 80
        var karanaName = "Bava";        // KaranaScore -> 75
        var mahaLord = "Sun";
        var antarLord = "Sun";          // own antardasha -> 80
        var jupiterHouse = 11;          // JupiterTransitScore -> 80
        var saturnHouse = 11;           // SaturnTransitScore -> 80
        var rahuHouse = 11;             // NodeTransitScore -> 75
        var ketuHouse = 11;             // NodeTransitScore -> 75

        var expectedMoon = 90;
        var expectedPanchang = (int)Math.Round(90 * 0.40 + 80 * 0.35 + 75 * 0.25); // 84
        var expectedDasha = 80;
        var expectedTransits = (int)Math.Round((80 + 80 + 75 + 75) / 4.0); // 78
        var expectedTotal = (int)Math.Round(expectedMoon * 0.30 + expectedPanchang * 0.25 + expectedDasha * 0.25 + expectedTransits * 0.20);

        var result = _service.Score(moonHouseFromMoon, tithiIndex, yogaIndex, karanaName, mahaLord, antarLord,
            jupiterHouse, saturnHouse, rahuHouse, ketuHouse);

        Assert.Equal(expectedMoon, result.Breakdown.MoonTransit.Score);
        Assert.Equal(expectedPanchang, result.Breakdown.Panchang.Score);
        Assert.Equal(expectedDasha, result.Breakdown.Dasha.Score);
        Assert.Equal(expectedTransits, result.Breakdown.Transits.Score);
        Assert.Equal(expectedTotal, result.Score);
    }

    [Fact]
    public void Score_IsAlwaysWithinZeroToOneHundred()
    {
        for (var house = 1; house <= 12; house++)
        {
            var result = _service.Score(house, house % 5, 0, "Bava", "Sun", "Moon", house, house, house, house);
            Assert.InRange(result.Score, 0, 100);
        }
    }

    // The classical Naisargika Maitri table is NOT symmetric — Moon lists
    // Mercury as a friend, but Mercury lists Moon as an enemy. This is a
    // real, documented feature of the source table (see TrafficSignalTables.cs),
    // not a bug — worth locking in explicitly so a future "cleanup" doesn't
    // accidentally symmetrize it.
    [Fact]
    public void DashaRelationshipScore_MoonMercuryPair_IsDeliberatelyAsymmetric()
    {
        Assert.Equal(85, TrafficSignalTables.DashaRelationshipScore("Moon", "Mercury")); // friend
        Assert.Equal(25, TrafficSignalTables.DashaRelationshipScore("Mercury", "Moon")); // enemy
    }

    [Theory]
    [InlineData(1, 90)] [InlineData(3, 90)] [InlineData(6, 90)] [InlineData(7, 90)] [InlineData(10, 90)] [InlineData(11, 90)]
    [InlineData(2, 55)] [InlineData(5, 55)]
    [InlineData(8, 10)]
    [InlineData(9, 35)]
    [InlineData(4, 25)] [InlineData(12, 25)]
    public void ChandraBalaScore_MatchesTheVerifiedHouseTable(int house, int expected)
    {
        Assert.Equal(expected, TrafficSignalTables.ChandraBalaScore(house));
    }

    [Theory]
    [InlineData(0, 90)] [InlineData(5, 90)] [InlineData(10, 90)] // Nanda
    [InlineData(4, 90)] [InlineData(9, 90)] [InlineData(14, 90)] // Purna
    [InlineData(1, 75)] [InlineData(2, 75)] // Bhadra, Jaya
    [InlineData(3, 30)] [InlineData(8, 30)] [InlineData(13, 30)] // Rikta
    public void TithiTypeScore_MatchesTheVerifiedFiveFoldCycle(int tithiIndex, int expected)
    {
        Assert.Equal(expected, TrafficSignalTables.TithiTypeScore(tithiIndex));
    }

    [Fact]
    public void YogaScore_SeverestTwoYogas_ScoreLowestOfAll()
    {
        var vyatipata = TrafficSignalTables.YogaScore(16);
        var vaidhriti = TrafficSignalTables.YogaScore(26);
        var mildlyInauspicious = TrafficSignalTables.YogaScore(0);
        var auspicious = TrafficSignalTables.YogaScore(2);

        Assert.True(vyatipata < mildlyInauspicious);
        Assert.True(vaidhriti < mildlyInauspicious);
        Assert.True(mildlyInauspicious < auspicious);
    }

    [Fact]
    public void KaranaScore_Vishti_ScoresLowerThanEveryOtherKarana()
    {
        var vishtiScore = TrafficSignalTables.KaranaScore("Vishti");
        foreach (var name in new[] { "Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija",
                     "Kimstughna", "Shakuni", "Chatushpada", "Naga" })
        {
            Assert.True(vishtiScore < TrafficSignalTables.KaranaScore(name));
        }
    }
}

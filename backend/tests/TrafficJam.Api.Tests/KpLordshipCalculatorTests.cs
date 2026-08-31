using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class KpLordshipCalculatorTests
{
    [Theory]
    [InlineData(0.0, "Mars")]      // Aries
    [InlineData(90.0, "Moon")]     // Cancer
    [InlineData(120.0, "Sun")]     // Leo
    [InlineData(210.0, "Mars")]    // Scorpio
    [InlineData(300.0, "Saturn")]  // Aquarius
    public void Compute_SignLord_MatchesClassicalRashiRulership(double siderealLongitude, string expectedLord)
    {
        Assert.Equal(expectedLord, KpLordshipCalculator.Compute(siderealLongitude).SignLord);
    }

    [Fact]
    public void Compute_StarLord_MatchesTheSameNakshatraLordRuleDashaUses()
    {
        // 0° Ashwini (nakshatraIndex 0, 0 % 9 = 0) -> Ketu, the same rule
        // VimshottariDashaService uses to pick the birth Mahadasha lord.
        Assert.Equal("Ketu", KpLordshipCalculator.Compute(0.0).StarLord);
        Assert.Equal(VimshottariConstants.Lords[0], KpLordshipCalculator.Compute(0.0).StarLord);
    }

    [Fact]
    public void Compute_SubLord_AtTheStartOfANakshatra_EqualsTheStarLordItself()
    {
        // The first Sub of any Nakshatra always belongs to that Nakshatra's
        // own Star Lord — the same "own antardasha starts with itself" shape
        // as VimshottariDashaService's Maha->Antar rule.
        var atZero = KpLordshipCalculator.Compute(0.0); // Ashwini, star lord Ketu
        Assert.Equal(atZero.StarLord, atZero.SubLord);
    }

    [Fact]
    public void Compute_SubSubLord_AtTheStartOfASub_EqualsTheSubLordItself()
    {
        var atZero = KpLordshipCalculator.Compute(0.0);
        Assert.Equal(atZero.SubLord, atZero.SubSubLord);
    }

    // Walking across every Sub boundary within one Nakshatra should visit
    // the 9 lords starting from that Nakshatra's own Star Lord, in the fixed
    // Vimshottari order, each Sub's width proportional to its Vimshottari
    // years — the exact same proportional rule as Dasha, just in degrees.
    [Fact]
    public void Compute_SubLord_WalksTheNineLordsInFixedOrderProportionally()
    {
        var nakshatraSpan = VedicMath.NakshatraSpanDegrees;
        var startLordIndex = 0; // Ashwini -> Ketu
        var cursor = 0.0;
        for (var i = 0; i < 9; i++)
        {
            var lordIndex = (startLordIndex + i) % 9;
            var partSpan = nakshatraSpan * VimshottariConstants.Years[lordIndex] / 120.0;
            var midOfPart = cursor + partSpan / 2.0; // safely inside this part, away from boundary rounding
            Assert.Equal(VimshottariConstants.Lords[lordIndex], KpLordshipCalculator.Compute(midOfPart).SubLord);
            cursor += partSpan;
        }

        Assert.Equal(nakshatraSpan, cursor, precision: 9); // the 9 parts sum to exactly the Nakshatra span
    }

    [Fact]
    public void Compute_IsConsistentAcrossTheFullZodiac_NoExceptionsAnywhere()
    {
        // Sweep finely enough to cross every Sign/Nakshatra/Sub/Sub-Sub
        // boundary at least once — a real regression net against an
        // off-by-one in any of the four subdivision levels throwing or
        // returning something outside the expected 9 lords.
        for (var lon = 0.0; lon < 360.0; lon += 0.37)
        {
            var lordship = KpLordshipCalculator.Compute(lon);
            Assert.Contains(lordship.SignLord, new[] { "Mars", "Venus", "Mercury", "Moon", "Sun", "Jupiter", "Saturn" });
            Assert.Contains(lordship.StarLord, VimshottariConstants.Lords);
            Assert.Contains(lordship.SubLord, VimshottariConstants.Lords);
            Assert.Contains(lordship.SubSubLord, VimshottariConstants.Lords);
        }
    }
}

using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

public class VedicMathTests
{
    [Theory]
    [InlineData(0, 0)]      // 0° Aries -> sign 0
    [InlineData(29.999, 0)] // still Aries just under the boundary
    [InlineData(30, 1)]     // exactly the Taurus boundary
    [InlineData(359.999, 11)] // still Pisces just under wraparound
    [InlineData(360, 0)]      // wraps back to Aries
    [InlineData(-30, 11)]     // negative input normalizes into Pisces
    public void SignIndex_HandlesBoundariesAndWraparound(double longitude, int expectedSign)
    {
        Assert.Equal(expectedSign, VedicMath.SignIndex(longitude));
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(6, 6)]
    [InlineData(11, 11)]
    public void HouseFromSign_ASignInItself_IsAlwaysHouseOne(int referenceSign, int sameSign)
    {
        Assert.Equal(1, VedicMath.HouseFromSign(sameSign, referenceSign));
    }

    [Theory]
    [InlineData(0, 0, 1)]   // same sign as reference -> house 1
    [InlineData(1, 0, 2)]   // next sign over -> house 2
    [InlineData(11, 0, 12)] // one sign behind -> house 12 (wraps backward)
    [InlineData(0, 11, 2)]  // reference in Pisces(11), sign in Aries(0) -> house 2 (wraps forward)
    public void HouseFromSign_CountsForwardFromTheReferenceSign(int signIndex, int referenceSignIndex, int expectedHouse)
    {
        Assert.Equal(expectedHouse, VedicMath.HouseFromSign(signIndex, referenceSignIndex));
    }

    [Fact]
    public void Nakshatra_FirstDegreeOfZodiac_IsAshwiniPada1()
    {
        var (index, pada) = VedicMath.Nakshatra(0.0);
        Assert.Equal(0, index);
        Assert.Equal("Ashwini", VedicMath.NakshatraNames[index]);
        Assert.Equal(1, pada);
    }

    [Fact]
    public void Nakshatra_LastDegreeOfZodiac_IsRevatiPada4()
    {
        var (index, pada) = VedicMath.Nakshatra(359.99);
        Assert.Equal(26, index);
        Assert.Equal("Revati", VedicMath.NakshatraNames[index]);
        Assert.Equal(4, pada);
    }

    [Fact]
    public void Nakshatra_HasExactly27Names()
    {
        Assert.Equal(27, VedicMath.NakshatraNames.Length);
    }

    // Verified against the classical movable/fixed/dual Navamsha starting-
    // sign rule (see VedicMath.NavamshaSignIndex's doc comment) for one
    // example of each modality.
    [Theory]
    [InlineData(0.0, 0)]     // Aries (movable) 1st navamsha -> Aries
    [InlineData(5.0, 1)]     // Aries 2nd navamsha -> Taurus
    [InlineData(27.0, 8)]    // Aries 9th navamsha -> Sagittarius
    [InlineData(30.0, 9)]    // Taurus (fixed) 1st navamsha -> Capricorn
    [InlineData(34.0, 10)]   // Taurus 2nd navamsha -> Aquarius
    [InlineData(60.0, 6)]    // Gemini (dual) 1st navamsha -> Libra
    public void NavamshaSignIndex_MatchesClassicalRule(double siderealLongitude, int expectedSign)
    {
        Assert.Equal(expectedSign, VedicMath.NavamshaSignIndex(siderealLongitude));
    }

    // Verified against an independent open-source implementation
    // (northtara/jyotishganit's dasamsa_from_long) and worked examples from
    // classical sources — see VedicMath.DashamshaSignIndex's doc comment.
    [Theory]
    [InlineData(2.0, 0)]     // Aries (odd) 2° -> 1st Dashamsha -> Aries itself
    [InlineData(29.0, 9)]    // Aries 10th Dashamsha (27-30°) -> Capricorn
    [InlineData(32.0, 9)]    // Taurus (even) 2° -> 1st Dashamsha -> Capricorn (worked example)
    [InlineData(34.0, 10)]   // Taurus 2nd Dashamsha (33-36°) -> Aquarius
    public void DashamshaSignIndex_MatchesClassicalRule(double siderealLongitude, int expectedSign)
    {
        Assert.Equal(expectedSign, VedicMath.DashamshaSignIndex(siderealLongitude));
    }

    // D60 uses a uniform (no odd/even reversal) same-sign-start rule — see
    // VedicMath.ShastiamshaSignIndex's doc comment for why this specific
    // convention was chosen among several genuinely disputed ones.
    [Theory]
    [InlineData(0.0, 0)]    // Aries 1st Shashtiamsha -> Aries itself
    [InlineData(0.5, 1)]    // Aries 2nd Shashtiamsha -> Taurus
    [InlineData(6.0, 0)]    // Aries 13th Shashtiamsha -> wraps once through 12 signs, back to Aries
    [InlineData(30.0, 1)]   // Taurus (even) 1st Shashtiamsha -> Taurus itself (no reversal)
    public void ShastiamshaSignIndex_MatchesTheChosenUniformRule(double siderealLongitude, int expectedSign)
    {
        Assert.Equal(expectedSign, VedicMath.ShastiamshaSignIndex(siderealLongitude));
    }

    [Fact]
    public void Normalize_WrapsArbitraryValuesIntoZeroTo360()
    {
        Assert.Equal(0.0, VedicMath.Normalize(360.0), precision: 9);
        Assert.Equal(10.0, VedicMath.Normalize(370.0), precision: 9);
        Assert.Equal(350.0, VedicMath.Normalize(-10.0), precision: 9);
    }

    // ── Whole-zodiac sweeps ──────────────────────────────────────────────
    //
    // The [Theory] cases above check a handful of hand-picked longitudes. That
    // catches a wrong rule and nothing else; a varga formula goes wrong at a
    // division boundary, and there are 108/120/720 of those. These walk every
    // single division and check the classical rule holds in all of them.
    //
    // Each division is sampled at its MIDPOINT rather than on a grid of round
    // longitudes. A round longitude can land exactly on a boundary, where the
    // answer legitimately depends on which side of it a double falls — 23°20'
    // written as 1400/60.0 is 1.2e-15° *below* the true boundary, so the lower
    // division is genuinely correct there and an exact-arithmetic expectation
    // would wrongly fail. Midpoints have no such ambiguity, and the boundaries
    // themselves are covered structurally by the sign-change counts below.

    private static void AssertVargaAcrossEveryDivision(
        int divisionsPerSign, Func<double, int> actual, Func<int, int, int> expected)
    {
        var width = 30.0 / divisionsPerSign;
        for (var sign = 0; sign < 12; sign++)
        {
            for (var part = 0; part < divisionsPerSign; part++)
            {
                var longitude = sign * 30.0 + part * width + width / 2.0;
                Assert.Equal(expected(sign, part), actual(longitude));
            }
        }
    }

    [Fact]
    public void NavamshaSignIndex_MatchesTheClassicalRule_InEveryDivision()
    {
        // Movable signs count from themselves, fixed from the 9th, dual from the 5th.
        AssertVargaAcrossEveryDivision(9, VedicMath.NavamshaSignIndex, (sign, part) =>
        {
            var start = (sign % 3) switch { 0 => sign, 1 => (sign + 8) % 12, _ => (sign + 4) % 12 };
            return (start + part) % 12;
        });
    }

    [Fact]
    public void DashamshaSignIndex_MatchesTheClassicalRule_InEveryDivision()
    {
        // Odd signs count from themselves, even signs from the 9th.
        AssertVargaAcrossEveryDivision(10, VedicMath.DashamshaSignIndex, (sign, part) =>
            ((sign % 2 == 0 ? sign : (sign + 8) % 12) + part) % 12);
    }

    [Fact]
    public void ShastiamshaSignIndex_MatchesTheChosenRule_InEveryDivision()
    {
        // Uniform, no odd/even reversal — a documented convention choice, see
        // VedicMath.ShastiamshaSignIndex.
        AssertVargaAcrossEveryDivision(60, VedicMath.ShastiamshaSignIndex, (sign, part) =>
            (sign + part) % 12);
    }

    // A structural consequence of each rule, independent of the rule's own
    // arithmetic — so this still fails if a bug were mirrored into the
    // expectations above, and it exercises the boundaries the midpoint sweeps
    // deliberately skip.
    //
    // D9's 108 divisions each land on a different sign from the last, so the
    // sign changes at all 107 interior boundaries. D10 has 120, but where an
    // odd sign hands over to an even one, its last part and the next sign's
    // first part resolve to the same sign — that happens at 6 of the 12 sign
    // boundaries, giving 119 - 6 = 113. D60's 720 divisions all differ.
    [Theory]
    [InlineData("d9", 107)]
    [InlineData("d10", 113)]
    [InlineData("d60", 719)]
    public void VargaSignChanges_PerCircle_MatchTheDivisionStructure(string varga, int expectedChanges)
    {
        Func<double, int> fn = varga switch
        {
            "d9" => VedicMath.NavamshaSignIndex,
            "d10" => VedicMath.DashamshaSignIndex,
            _ => VedicMath.ShastiamshaSignIndex,
        };

        const int arcminutesPerCircle = 360 * 60;
        var changes = 0;
        var previous = fn(0.0);
        for (var m = 1; m < arcminutesPerCircle; m++)
        {
            var current = fn(m / 60.0);
            if (current != previous) changes++;
            previous = current;
        }

        Assert.Equal(expectedChanges, changes);
    }
}

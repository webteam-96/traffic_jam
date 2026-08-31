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
}

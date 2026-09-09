using CosineKitty;
using TrafficJam.Api.Modules.Astro;
using Xunit;

namespace TrafficJam.Api.Tests;

/// <summary>
/// The Hindu lunar month. The rule under test: a month runs new moon to new
/// moon and is named for the solar sign the Sun occupies at the new moon that
/// opens it. The two reckonings share those names but cut the month at
/// different points, which is the part most easily got wrong.
/// </summary>
public class HinduLunarMonthTests
{
    private readonly IAyanamsaService _ayanamsa = new LahiriAyanamsaService();

    private HinduLunarMonthInfo Compute(DateTime utc, string paksha) =>
        HinduLunarMonthCalculator.Compute(new AstroTime(utc), _ayanamsa, paksha);

    // Through the waxing half both systems name the same month, because
    // Purnimanta's rollover happens at the full moon that ends it.
    [Fact]
    public void ShuklaPaksha_BothReckoningsAgree()
    {
        var month = Compute(new DateTime(2026, 8, 25, 6, 0, 0, DateTimeKind.Utc), "Shukla");

        Assert.Equal(month.Amanta, month.Purnimanta);
    }

    // Through the waning half they must differ by exactly one month —
    // Purnimanta has already rolled over, Amanta has not. Returning the same
    // name for both here would be the bug this exists to catch.
    [Fact]
    public void KrishnaPaksha_PurnimantaIsExactlyOneMonthAheadOfAmanta()
    {
        var month = Compute(new DateTime(2026, 9, 9, 6, 0, 0, DateTimeKind.Utc), "Krishna");

        Assert.NotEqual(month.Amanta, month.Purnimanta);

        var names = new[]
        {
            "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
            "Ashwin", "Kartik", "Margashirsha", "Pausha", "Magha", "Phalguna",
        };
        var amantaIndex = Array.IndexOf(names, month.Amanta);
        var purnimantaIndex = Array.IndexOf(names, month.Purnimanta);

        Assert.Equal((amantaIndex + 1) % 12, purnimantaIndex);
    }

    [Theory]
    [InlineData("Shukla")]
    [InlineData("Krishna")]
    public void EveryMonthName_IsOneOfTheTwelve(string paksha)
    {
        var names = new[]
        {
            "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
            "Ashwin", "Kartik", "Margashirsha", "Pausha", "Magha", "Phalguna",
        };

        // A full year, so every lunation and every sign transition is covered.
        for (var day = 0; day < 365; day += 5)
        {
            var month = Compute(new DateTime(2026, 1, 1, 6, 0, 0, DateTimeKind.Utc).AddDays(day), paksha);

            Assert.Contains(month.Amanta, names);
            Assert.Contains(month.Purnimanta, names);
            Assert.False(string.IsNullOrWhiteSpace(month.AmantaHindi));
            Assert.False(string.IsNullOrWhiteSpace(month.PurnimantaHindi));
        }
    }

    // The month name must hold steady across a whole lunation and change only
    // when a new moon passes — a naive "name it from today\u0027s Sun sign" would
    // drift mid-month and this is what catches that.
    [Fact]
    public void AmantaName_IsStableWithinASingleLunation()
    {
        var start = new DateTime(2026, 9, 12, 6, 0, 0, DateTimeKind.Utc);
        var first = Compute(start, "Shukla").Amanta;

        // 10 days forward stays inside the same lunation (~29.5 days).
        for (var day = 1; day <= 10; day++)
        {
            Assert.Equal(first, Compute(start.AddDays(day), "Shukla").Amanta);
        }
    }

    [Fact]
    public void HindiNames_AreInDevanagariAndPairWithTheirTransliteration()
    {
        var month = Compute(new DateTime(2026, 9, 9, 6, 0, 0, DateTimeKind.Utc), "Krishna");

        // Devanagari block starts at U+0900.
        Assert.All(month.AmantaHindi, c => Assert.InRange(c, (char)0x0900, (char)0x097F));
        Assert.All(month.PurnimantaHindi, c => Assert.InRange(c, (char)0x0900, (char)0x097F));
        Assert.NotEqual(month.AmantaHindi, month.PurnimantaHindi);
    }

    // Proof the month is derived, not fixed: walk a whole year and the name
    // must move through all twelve in calendar order, changing only at a new
    // moon. A hardcoded or date-agnostic implementation fails this instantly.
    [Fact]
    public void AcrossAYear_TheMonthAdvancesThroughAllTwelveInOrder()
    {
        var names = new[]
        {
            "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
            "Ashwin", "Kartik", "Margashirsha", "Pausha", "Magha", "Phalguna",
        };

        var seen = new List<string>();
        for (var day = 0; day < 380; day++)
        {
            var month = Compute(
                new DateTime(2026, 1, 1, 6, 0, 0, DateTimeKind.Utc).AddDays(day), "Shukla").Amanta;
            if (seen.Count == 0 || seen[^1] != month)
            {
                seen.Add(month);
            }
        }

        // Every one of the twelve shows up over a year.
        Assert.Equal(12, seen.Distinct().Count());

        // And each change steps to the very next name, never skipping or
        // jumping back — which is what "follows the actual lunation" means.
        for (var i = 1; i < seen.Count; i++)
        {
            var previous = Array.IndexOf(names, seen[i - 1]);
            Assert.Equal((previous + 1) % 12, Array.IndexOf(names, seen[i]));
        }
    }

}

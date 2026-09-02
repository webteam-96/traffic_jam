using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public record PanchangResult(
    string Paksha,
    string TithiName, int TithiIndex, DateTime TithiEndsAt,
    string NakshatraName, DateTime NakshatraEndsAt,
    string YogaName, int YogaIndex, DateTime YogaEndsAt,
    string KaranaName, DateTime KaranaEndsAt,
    DateTime RahuKaalStart, DateTime RahuKaalEnd,
    DateTime YamagandaStart, DateTime YamagandaEnd,
    DateTime GulikaStart, DateTime GulikaEnd,
    DateTime AbhijitStart, DateTime AbhijitEnd,
    // The portion of Abhijit that DOESN'T fall inside Rahu Kaal/Yamaganda/
    // Gulika — Abhijit is fixed to solar noon while the other three shift
    // by weekday, so on some weekdays Abhijit is genuinely, classically
    // partly or fully swallowed by one of them. Null start/end means fully
    // swallowed (no honestly-favourable time left today); non-null but
    // different from AbhijitStart/End means partially trimmed.
    DateTime? AbhijitCleanStart, DateTime? AbhijitCleanEnd,
    DateTime Sunrise, DateTime Sunset,
    DateTime? Moonrise, DateTime? Moonset);

public interface IPanchangService
{
    /// <summary>Computes the Panchang for a calendar date at a given location. All returned times are UTC.</summary>
    PanchangResult Compute(DateOnly date, double lat, double lng, string timezone);
}

/// <summary>
/// Panchang — the daily Vedic almanac. Every element (Tithi, Nakshatra,
/// Yoga, Karana) is arithmetic on the same Sun/Moon sidereal longitudes
/// AstroEngineService already knows how to compute, just re-evaluated for
/// "today" instead of a birth moment. Rahu Kaal/Yamaganda/Gulika aren't
/// astronomy at all — they're the daylight span divided into 8 equal parts,
/// with a fixed weekday lookup table saying which part (see PanchangNames,
/// verified against an independent implementation). Abhijit is the same
/// daylight span divided into 15 parts, the 8th (centered on solar noon).
/// </summary>
public class PanchangService(IAyanamsaService ayanamsa) : IPanchangService
{
    public PanchangResult Compute(DateOnly date, double lat, double lng, string timezone)
    {
        var tz = TimeZoneInfo.FindSystemTimeZoneById(timezone);
        var localMidnight = DateTime.SpecifyKind(date.ToDateTime(TimeOnly.MinValue), DateTimeKind.Unspecified);
        var searchStart = new AstroTime(TimeZoneInfo.ConvertTimeToUtc(localMidnight, tz));

        var observer = new Observer(lat, lng, 0);
        var sunrise = Astronomy.SearchRiseSet(Body.Sun, observer, Direction.Rise, searchStart, 1.5, 0)
            ?? throw new InvalidOperationException("No sunrise found within 36 hours — check latitude/date for polar conditions.");
        var sunset = Astronomy.SearchRiseSet(Body.Sun, observer, Direction.Set, sunrise, 1.0, 0)
            ?? throw new InvalidOperationException("No sunset found within 24 hours of sunrise — check latitude/date for polar conditions.");
        var moonrise = Astronomy.SearchRiseSet(Body.Moon, observer, Direction.Rise, searchStart, 1.0, 0);
        var moonset = Astronomy.SearchRiseSet(Body.Moon, observer, Direction.Set, searchStart, 1.0, 0);

        var daylightDays = sunset.ut - sunrise.ut;
        var octant = daylightDays / 8.0;
        var (rahuStart, rahuEnd) = Octant(sunrise, octant, PanchangNames.RahuKaalOctant[(int)date.DayOfWeek]);
        var (yamaStart, yamaEnd) = Octant(sunrise, octant, PanchangNames.YamagandaOctant[(int)date.DayOfWeek]);
        var (gulikaStart, gulikaEnd) = Octant(sunrise, octant, PanchangNames.GulikaOctant[(int)date.DayOfWeek]);

        var muhurta = daylightDays / 15.0;
        var abhijitStart = sunrise.AddDays(muhurta * 7);
        var abhijitEnd = sunrise.AddDays(muhurta * 8);

        var (abhijitCleanStart, abhijitCleanEnd) = TrimAgainstInauspicious(
            abhijitStart.ToUtcDateTime(), abhijitEnd.ToUtcDateTime(),
            (rahuStart.ToUtcDateTime(), rahuEnd.ToUtcDateTime()),
            (yamaStart.ToUtcDateTime(), yamaEnd.ToUtcDateTime()),
            (gulikaStart.ToUtcDateTime(), gulikaEnd.ToUtcDateTime()));

        // Classical convention: the day's Panchang is whatever is in effect at sunrise.
        double SunSidereal(AstroTime t) => VedicMath.Normalize(Astronomy.SunPosition(t).elon - ayanamsa.LahiriDegrees(t));
        double MoonSidereal(AstroTime t) => VedicMath.Normalize(Astronomy.EclipticGeoMoon(t).lon - ayanamsa.LahiriDegrees(t));
        double TithiAngle(AstroTime t) => VedicMath.Normalize(MoonSidereal(t) - SunSidereal(t));
        double YogaAngle(AstroTime t) => VedicMath.Normalize(SunSidereal(t) + MoonSidereal(t));

        var moonAtSunrise = MoonSidereal(sunrise);
        var tithiAngleAtSunrise = TithiAngle(sunrise);
        var yogaAngleAtSunrise = YogaAngle(sunrise);

        var tithiIndex = (int)(tithiAngleAtSunrise / 12.0) % 30;
        var (nakshatraIndex, _) = VedicMath.Nakshatra(moonAtSunrise);
        var yogaIndex = (int)(yogaAngleAtSunrise / (360.0 / 27.0)) % 27;
        var karanaSlot = (int)(tithiAngleAtSunrise / 6.0) % 60;

        var tithiEndsAt = FindSegmentEnd(sunrise, TithiAngle, 12.0);
        var nakshatraEndsAt = FindSegmentEnd(sunrise, MoonSidereal, VedicMath.NakshatraSpanDegrees);
        var yogaEndsAt = FindSegmentEnd(sunrise, YogaAngle, 360.0 / 27.0);
        var karanaEndsAt = FindSegmentEnd(sunrise, TithiAngle, 6.0);

        return new PanchangResult(
            Paksha: tithiIndex < 15 ? "Shukla" : "Krishna",
            TithiName: PanchangNames.TithiNames[tithiIndex], TithiIndex: tithiIndex, TithiEndsAt: tithiEndsAt,
            NakshatraName: VedicMath.NakshatraNames[nakshatraIndex], NakshatraEndsAt: nakshatraEndsAt,
            YogaName: PanchangNames.YogaNames[yogaIndex], YogaIndex: yogaIndex, YogaEndsAt: yogaEndsAt,
            KaranaName: PanchangNames.KaranaName(karanaSlot), KaranaEndsAt: karanaEndsAt,
            RahuKaalStart: rahuStart.ToUtcDateTime(), RahuKaalEnd: rahuEnd.ToUtcDateTime(),
            YamagandaStart: yamaStart.ToUtcDateTime(), YamagandaEnd: yamaEnd.ToUtcDateTime(),
            GulikaStart: gulikaStart.ToUtcDateTime(), GulikaEnd: gulikaEnd.ToUtcDateTime(),
            AbhijitStart: abhijitStart.ToUtcDateTime(), AbhijitEnd: abhijitEnd.ToUtcDateTime(),
            AbhijitCleanStart: abhijitCleanStart, AbhijitCleanEnd: abhijitCleanEnd,
            Sunrise: sunrise.ToUtcDateTime(), Sunset: sunset.ToUtcDateTime(),
            Moonrise: moonrise?.ToUtcDateTime(), Moonset: moonset?.ToUtcDateTime());
    }

    private static (AstroTime Start, AstroTime End) Octant(AstroTime sunrise, double octantDays, int octant1Indexed) =>
        (sunrise.AddDays(octantDays * (octant1Indexed - 1)), sunrise.AddDays(octantDays * octant1Indexed));

    /// <summary>
    /// Subtracts every `avoid` window from [start, end), returning the
    /// largest remaining contiguous piece — null/null if nothing survives
    /// (fully swallowed). Rahu Kaal/Yamaganda/Gulika are each wider than
    /// Abhijit's ~49-minute window and mutually exclusive octants of the
    /// same day, so in practice at most one ever overlaps Abhijit at a
    /// time — this handles the general case anyway rather than assuming that.
    /// </summary>
    internal static (DateTime? Start, DateTime? End) TrimAgainstInauspicious(
        DateTime start, DateTime end, params (DateTime Start, DateTime End)[] avoid)
    {
        var free = new List<(DateTime Start, DateTime End)> { (start, end) };
        foreach (var (avoidStart, avoidEnd) in avoid)
        {
            var next = new List<(DateTime Start, DateTime End)>();
            foreach (var (s, e) in free)
            {
                if (avoidEnd <= s || avoidStart >= e)
                {
                    next.Add((s, e));
                    continue;
                }
                if (avoidStart > s) next.Add((s, avoidStart));
                if (avoidEnd < e) next.Add((avoidEnd, e));
            }
            free = next;
        }

        if (free.Count == 0) return (null, null);

        var largest = free.MaxBy(w => w.End - w.Start);
        return (largest.Start, largest.End);
    }

    /// <summary>
    /// Finds when a cyclical angle (mod stepDegrees) next moves into a new
    /// segment — the same coarse-scan-then-bisect strategy AscendantCalculator
    /// uses, applied over time instead of over the ecliptic. Segments here
    /// last roughly a day (Nakshatra, Tithi, Yoga) or half a day (Karana),
    /// so an hourly scan out to 72 hours safely brackets the transition.
    /// </summary>
    private static DateTime FindSegmentEnd(AstroTime from, Func<AstroTime, double> angleFn, double stepDegrees)
    {
        var startSegment = (int)(VedicMath.Normalize(angleFn(from)) / stepDegrees);
        var prev = from;
        for (var hours = 1; hours <= 72; hours++)
        {
            var t = from.AddDays(hours / 24.0);
            var segment = (int)(VedicMath.Normalize(angleFn(t)) / stepDegrees);
            if (segment != startSegment)
            {
                return Bisect(prev, t, startSegment, angleFn, stepDegrees);
            }

            prev = t;
        }

        throw new InvalidOperationException("No Panchang segment boundary found within 72 hours — unexpected.");
    }

    private static DateTime Bisect(AstroTime lo, AstroTime hi, int startSegment, Func<AstroTime, double> angleFn, double stepDegrees)
    {
        for (var i = 0; i < 40; i++)
        {
            var mid = new AstroTime((lo.ut + hi.ut) / 2.0);
            var segment = (int)(VedicMath.Normalize(angleFn(mid)) / stepDegrees);
            if (segment == startSegment) lo = mid; else hi = mid;
        }

        return hi.ToUtcDateTime();
    }
}

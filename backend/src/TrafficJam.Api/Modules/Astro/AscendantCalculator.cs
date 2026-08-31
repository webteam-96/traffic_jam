using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public interface IAscendantCalculator
{
    /// <summary>Tropical ecliptic longitude of the Ascendant (Lagna), in degrees.</summary>
    double TropicalAscendant(AstroTime time, double latitude, double longitude);
}

/// <summary>
/// Finds the Ascendant by numerically searching the ecliptic for the point
/// currently crossing the eastern horizon, using only Astronomy Engine's own
/// verified coordinate-rotation primitives (ecliptic-of-date -> equator-of-
/// date -> horizontal). This deliberately avoids hand-deriving the classical
/// RAMC/obliquity/latitude trig formula from scratch — every step here is a
/// library-provided rotation, so the only original logic is the root-find
/// itself. Verified in AscendantCalculatorTests against the geometric fact
/// that at the moment of sunrise, the Ascendant must sit very close to the
/// Sun's own tropical longitude (the Sun IS the thing rising).
/// </summary>
public class AscendantCalculator : IAscendantCalculator
{
    public double TropicalAscendant(AstroTime time, double latitude, double longitude)
    {
        var observer = new Observer(latitude, longitude, 0);
        var eclToHorizon = Astronomy.CombineRotation(
            Astronomy.Rotation_ECT_EQD(time),
            Astronomy.Rotation_EQD_HOR(time, observer));

        double Altitude(double eclipticLongitudeDeg)
        {
            var rad = eclipticLongitudeDeg * Math.PI / 180.0;
            var eclVector = new AstroVector(Math.Cos(rad), Math.Sin(rad), 0, time);
            var horVector = Astronomy.RotateVector(eclToHorizon, eclVector);
            return Astronomy.HorizonFromVector(horVector, Refraction.None).lat; // altitude
        }

        double Azimuth(double eclipticLongitudeDeg)
        {
            var rad = eclipticLongitudeDeg * Math.PI / 180.0;
            var eclVector = new AstroVector(Math.Cos(rad), Math.Sin(rad), 0, time);
            var horVector = Astronomy.RotateVector(eclToHorizon, eclVector);
            return Astronomy.HorizonFromVector(horVector, Refraction.None).lon; // azimuth
        }

        // Sample the whole ecliptic circle to bracket the (usually two)
        // altitude=0 crossings, then refine each with bisection.
        const int sampleCount = 360;
        var candidates = new List<double>();
        var prevLon = 0.0;
        var prevAlt = Altitude(0.0);
        for (var i = 1; i <= sampleCount; i++)
        {
            var lon = i * 360.0 / sampleCount;
            var alt = Altitude(lon);
            if (Math.Sign(alt) != Math.Sign(prevAlt))
            {
                candidates.Add(Bisect(prevLon, lon, prevAlt, alt, Altitude));
            }

            prevLon = lon;
            prevAlt = alt;
        }

        if (candidates.Count == 0)
        {
            throw new InvalidOperationException(
                "No horizon crossing found on the ecliptic — unexpected for any real birth location.");
        }

        // The Ascendant is the crossing nearest due east (azimuth 90); the
        // other crossing (nearest azimuth 270) is the Descendant.
        return candidates
            .OrderBy(lon => AngularDistance(Azimuth(lon), 90.0))
            .First();
    }

    private static double Bisect(double loLon, double hiLon, double loAlt, double hiAlt, Func<double, double> altitude)
    {
        for (var i = 0; i < 40; i++)
        {
            var midLon = (loLon + hiLon) / 2.0;
            var midAlt = altitude(midLon);
            if (Math.Sign(midAlt) == Math.Sign(loAlt))
            {
                loLon = midLon;
                loAlt = midAlt;
            }
            else
            {
                hiLon = midLon;
                hiAlt = midAlt;
            }
        }

        return (loLon + hiLon) / 2.0;
    }

    private static double AngularDistance(double a, double b)
    {
        var diff = Math.Abs(VedicMath.Normalize(a) - VedicMath.Normalize(b)) % 360.0;
        return diff > 180.0 ? 360.0 - diff : diff;
    }
}

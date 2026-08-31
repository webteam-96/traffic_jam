using CosineKitty;

namespace TrafficJam.Api.Modules.Astro;

public interface IPlacidusHouseCalculator
{
    /// <summary>Tropical ecliptic longitude of each of the 12 house cusps, index 0 = house 1 (Ascendant).</summary>
    double[] Cusps(AstroTime time, double latitude, double longitude);
}

/// <summary>
/// Placidus house cusps — KP astrology's house system (distinct from the
/// whole-sign houses used everywhere else in this app; see
/// BACKEND_REQUIREMENTS.md's KP System requirement). Cusps 1 (Ascendant), 4
/// (IC), 7 (Descendant), and 10 (MC) have direct definitions; cusps 11, 12,
/// 2, 3 require solving a transcendental equation (no closed form) via the
/// classical "temporal hours" definition — a cusp's hour angle is a fixed
/// fraction (1/3 or 2/3) of its own semi-diurnal or semi-nocturnal arc, and
/// that arc itself depends on the very declination the candidate longitude
/// produces. Cusps 5, 6, 8, 9 are then exactly 180° from 11, 12, 2, 3 (a
/// well-known point symmetry across the ecliptic, not an approximation).
///
/// Deliberately uses the same technique as AscendantCalculator — numerically
/// searching the ecliptic via Astronomy Engine's own rotation primitives
/// (ECT/EQD, right ascension/declination) rather than hand-deriving the
/// classical closed-form trig chain — for the same reason: fewer places for
/// a hand-transcribed formula to go subtly wrong. Verified in
/// PlacidusHouseCalculatorTests by cross-checking cusp 1 against the
/// independently-built AscendantCalculator (they must agree, since both
/// compute the same "point currently rising" condition via different code
/// paths) and cusp 10 against the direct MC definition.
/// </summary>
public class PlacidusHouseCalculator(IAscendantCalculator ascendant) : IPlacidusHouseCalculator
{
    public double[] Cusps(AstroTime time, double latitude, double longitude)
    {
        var observer = new Observer(latitude, longitude, 0);
        var ramc = VedicMath.Normalize(Astronomy.SiderealTime(time) * 15.0 + longitude);

        var cusp1 = ascendant.TropicalAscendant(time, latitude, longitude);
        var cusp10 = FindMeridianCrossing(time, ramc);

        // Semi-diurnal-arc-based (above horizon, between MC and ASC):
        // targetFraction is how far *from MC toward rising* the cusp's own
        // hour angle sits (0 = at MC, 1 = at rise) — so house 11, adjacent
        // to MC, gets the smaller fraction and house 12, adjacent to the
        // Ascendant, gets the larger one. (Verified empirically, not just by
        // derivation — an earlier version of this had 11 and 12 swapped;
        // Cusps_11And12_FallBetweenMCAndAscendantInOrder caught it.)
        var cusp11 = FindCuspByHourAngle(time, latitude, ramc, targetFraction: 1.0 / 3.0, diurnal: true);
        var cusp12 = FindCuspByHourAngle(time, latitude, ramc, targetFraction: 2.0 / 3.0, diurnal: true);

        // Semi-nocturnal-arc-based (below horizon, between IC and ASC):
        // targetFraction is how far *from IC toward the next rising* the
        // cusp sits — house 3, adjacent to IC, gets the smaller fraction and
        // house 2, adjacent to the Ascendant, gets the larger one.
        var cusp2 = FindCuspByHourAngle(time, latitude, ramc, targetFraction: 2.0 / 3.0, diurnal: false);
        var cusp3 = FindCuspByHourAngle(time, latitude, ramc, targetFraction: 1.0 / 3.0, diurnal: false);

        // Index i (0-based) is house (i+1); the classical opposite-house
        // pairing is house N <-> house N+6, i.e. index i <-> index (i+6)%12 —
        // NOT "IC opposite Ascendant" (that pairing is wrong; IC is opposite
        // MC, and Descendant is opposite Ascendant). Get this backwards and
        // Cusps_OppositeHousesAreExactly180DegreesApart catches it immediately.
        var cusps = new double[12];
        cusps[0] = cusp1;   // house 1, Ascendant
        cusps[1] = cusp2;   // house 2
        cusps[2] = cusp3;   // house 3
        cusps[3] = VedicMath.Normalize(cusp10 + 180.0); // house 4, IC — opposite house 10 (MC)
        cusps[4] = VedicMath.Normalize(cusp11 + 180.0); // house 5 — opposite house 11
        cusps[5] = VedicMath.Normalize(cusp12 + 180.0); // house 6 — opposite house 12
        cusps[6] = VedicMath.Normalize(cusp1 + 180.0);  // house 7, Descendant — opposite house 1 (ASC)
        cusps[7] = VedicMath.Normalize(cusp2 + 180.0);  // house 8 — opposite house 2
        cusps[8] = VedicMath.Normalize(cusp3 + 180.0);  // house 9 — opposite house 3
        cusps[9] = cusp10;  // house 10, MC
        cusps[10] = cusp11; // house 11
        cusps[11] = cusp12; // house 12
        return cusps;
    }

    /// <summary>Right ascension (in degrees) and declination of the ecliptic point at longitude λ, at this moment.</summary>
    private static (double RaDeg, double Dec) EquatorialOf(AstroTime time, double eclipticLongitudeDeg)
    {
        var rad = eclipticLongitudeDeg * Math.PI / 180.0;
        var eclVector = new AstroVector(Math.Cos(rad), Math.Sin(rad), 0, time);
        var eqdVector = Astronomy.RotateVector(Astronomy.Rotation_ECT_EQD(time), eclVector);
        var eq = Astronomy.EquatorFromVector(eqdVector);
        return (VedicMath.Normalize(eq.ra * 15.0), eq.dec);
    }

    /// <summary>MC — the ecliptic point whose right ascension currently equals RAMC (on the meridian).</summary>
    private static double FindMeridianCrossing(AstroTime time, double ramc)
    {
        double SignedRaDiff(double lambda)
        {
            var (raDeg, _) = EquatorialOf(time, lambda);
            var diff = VedicMath.Normalize(raDeg - ramc);
            return diff > 180 ? diff - 360 : diff; // signed, in (-180, 180]
        }

        return Bisect(SignedRaDiff);
    }

    private static double FindCuspByHourAngle(AstroTime time, double latitude, double ramc, double targetFraction, bool diurnal)
    {
        // f(λ) = actual signed hour angle from the target the classical
        // "temporal hours" definition demands, given λ's own declination.
        double Deviation(double lambda)
        {
            var (raDeg, dec) = EquatorialOf(time, lambda);
            var hourAngle = VedicMath.Normalize(ramc - raDeg);
            if (hourAngle > 180) hourAngle -= 360; // signed, negative = east of meridian (not yet culminated)

            var tanProduct = Math.Clamp(Math.Tan(latitude * Math.PI / 180.0) * Math.Tan(dec * Math.PI / 180.0), -1.0, 1.0);
            double targetHourAngle;
            if (diurnal)
            {
                var sda = Math.Acos(-tanProduct) * 180.0 / Math.PI; // semi-diurnal arc
                targetHourAngle = -sda * targetFraction;
            }
            else
            {
                var sna = Math.Acos(tanProduct) * 180.0 / Math.PI; // semi-nocturnal arc
                targetHourAngle = 180.0 + sna * targetFraction;
                // hourAngle was normalized to (-180,180]; the nocturnal target
                // sits just past +180, so compare against the equivalent
                // negative representation for a continuous, bisectable function.
                targetHourAngle -= 360.0;
            }

            return hourAngle - targetHourAngle;
        }

        return Bisect(Deviation);
    }

    /// <summary>
    /// Coarse-scan-then-bisect for a signed function of ecliptic longitude
    /// that crosses zero exactly once per 360° sweep — the same strategy
    /// AscendantCalculator and PanchangService's segment-boundary search use.
    /// </summary>
    private static double Bisect(Func<double, double> signedDeviation)
    {
        var prevLon = 0.0;
        var prevVal = signedDeviation(0.0);
        for (var i = 1; i <= 360; i++)
        {
            var lon = i * 1.0;
            var val = signedDeviation(lon);

            // Both the hour-angle and RA-difference deviations are folded
            // into (-180, 180], which introduces an artificial ~360° jump
            // discontinuity somewhere in the sweep that is NOT a real root —
            // a genuine crossing changes by only a degree or two per 1° step
            // of λ, so a jump anywhere near 360 is unambiguously the fold
            // artifact, not a sign change to bisect on.
            var isRealCrossing = Math.Sign(val) != Math.Sign(prevVal) && Math.Abs(val - prevVal) < 180.0;
            if (isRealCrossing)
            {
                double lo = prevLon, hi = lon;
                var loVal = prevVal;
                for (var iter = 0; iter < 40; iter++)
                {
                    var mid = (lo + hi) / 2.0;
                    var midVal = signedDeviation(mid);
                    if (Math.Sign(midVal) == Math.Sign(loVal)) { lo = mid; loVal = midVal; }
                    else { hi = mid; }
                }

                return VedicMath.Normalize((lo + hi) / 2.0);
            }

            prevLon = lon;
            prevVal = val;
        }

        throw new InvalidOperationException("No sign crossing found on the ecliptic — unexpected for any real observer location.");
    }
}

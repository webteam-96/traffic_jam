namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// Static classical lookup tables the Traffic Signal score is built on. Each
/// table's *categories* (which houses/yogas/tithis/planet-pairs are
/// favorable vs. not) are sourced, documented classical astrology, not
/// invented — see the citation in each section. The exact 0-100 *numbers*
/// assigned to each category are this implementation's own reasonable
/// choice, since no source gives a numeric score — only a category. There
/// is no single universally-agreed formula for turning "auspicious/
/// inauspicious" into a percentage; this is a documented first pass, not a
/// claim of astrological authority.
/// </summary>
public static class TrafficSignalTables
{
    // ── Chandra Bala — favorability of today's Moon by house from natal Moon.
    // Houses 1,3,6,7,10,11 favorable; 2,5 neutral; 4,8,9,12 unfavorable, with
    // 8 (Chandrashtama) the most severe and 9 the mildest of the unfavorable set.
    public static int ChandraBalaScore(int houseFromMoon) => houseFromMoon switch
    {
        1 or 3 or 6 or 7 or 10 or 11 => 90,
        2 or 5 => 55,
        8 => 10,  // Chandrashtama — the classically worst single day of the cycle
        9 => 35,
        4 or 12 => 25,
        _ => throw new ArgumentOutOfRangeException(nameof(houseFromMoon)),
    };

    // ── Tithi type — the 30 tithis cycle through 5 types every 5 tithis
    // (Nanda, Bhadra, Jaya, Rikta, Purna), independent of Paksha. Nanda/Purna
    // are the most auspicious for new undertakings; Rikta ("empty") is the
    // one classically avoided for important work; Bhadra/Jaya are good but
    // more purpose-specific (social/philanthropic, competitive, respectively).
    public static int TithiTypeScore(int tithiIndex) => (tithiIndex % 5) switch
    {
        0 or 4 => 90, // Nanda, Purna
        1 or 2 => 75, // Bhadra, Jaya
        3 => 30,      // Rikta
        _ => throw new ArgumentOutOfRangeException(nameof(tithiIndex)),
    };

    // ── Yoga auspiciousness — 9 of the 27 Nitya Yogas are classically
    // inauspicious (Brihat Parashara Hora Shastra); Vyatipata and Vaidhriti
    // are the two "Maha Dosha" yogas, treated as an absolute contraindication
    // for new ventures. Indices are 0-based to match VedicMath.NakshatraNames-
    // style PanchangNames.YogaNames ordering (0=Vishkambha ... 26=Vaidhriti).
    private static readonly HashSet<int> MildlyInauspiciousYogas = [0, 5, 8, 9, 12, 14, 18]; // Vishkambha, Atiganda, Shoola, Ganda, Vyaghata, Vajra, Parigha
    private static readonly HashSet<int> SeverelyInauspiciousYogas = [16, 26]; // Vyatipata, Vaidhriti

    public static int YogaScore(int yogaIndex) =>
        SeverelyInauspiciousYogas.Contains(yogaIndex) ? 10
        : MildlyInauspiciousYogas.Contains(yogaIndex) ? 35
        : 80;

    // ── Karana — Vishti (Bhadra) is the one Karana universally cited as
    // inauspicious for starting new work; the other 10 are broadly neutral-to-good.
    public static int KaranaScore(string karanaName) => karanaName == "Vishti" ? 20 : 75;

    // ── Naisargika Maitri — permanent natural friendship between planets,
    // independent of any birth chart (classical, from Brihat Parashara Hora
    // Shastra). Deliberately NOT symmetric — e.g. Moon lists Mercury as a
    // friend, but Mercury lists Moon as an enemy; that asymmetry is itself a
    // real, well-documented feature of the classical table, not a bug.
    // Rahu/Ketu's table is less universally standardized across sources than
    // the 7-classical-planet table above — this uses the Parashara-attributed
    // version cited most consistently.
    private static readonly Dictionary<string, (string[] Friends, string[] Enemies)> NaturalFriendship = new()
    {
        ["Sun"] = (["Moon", "Mars", "Jupiter"], ["Saturn", "Venus"]),
        ["Moon"] = (["Sun", "Mercury"], []),
        ["Mars"] = (["Sun", "Moon", "Jupiter"], ["Mercury"]),
        ["Mercury"] = (["Sun", "Venus"], ["Moon"]),
        ["Jupiter"] = (["Sun", "Moon", "Mars"], ["Mercury", "Venus"]),
        ["Venus"] = (["Mercury", "Saturn"], ["Sun", "Moon"]),
        ["Saturn"] = (["Mercury", "Venus"], ["Sun", "Moon", "Mars"]),
        ["Rahu"] = (["Venus", "Saturn"], ["Sun", "Moon", "Mars"]),
        ["Ketu"] = (["Mars", "Venus", "Saturn"], ["Sun", "Moon"]),
    };

    public static int DashaRelationshipScore(string mahaLord, string antarLord)
    {
        if (mahaLord == antarLord) return 80; // a lord's own antardasha within its own mahadasha — stable, self-consistent
        var (friends, enemies) = NaturalFriendship[mahaLord];
        if (friends.Contains(antarLord)) return 85;
        if (enemies.Contains(antarLord)) return 25;
        return 55; // neutral
    }

    // ── Guru Gochar (Jupiter transit) house-from-Moon favorability.
    public static int JupiterTransitScore(int houseFromMoon) => houseFromMoon switch
    {
        2 or 5 or 7 or 9 or 11 => 80,
        6 or 8 or 12 => 25,
        _ => 55, // 1, 3, 4, 10 — not classically singled out either way
    };

    // ── Shani Gochar (Saturn transit) house-from-Moon favorability. 12/1/2
    // is Sade Sati (rising/peak/setting) — the most karmically stressful
    // ~7.5-year window in classical Vedic astrology.
    public static int SaturnTransitScore(int houseFromMoon) => houseFromMoon switch
    {
        3 or 6 or 11 => 80,
        12 or 1 or 2 => 15, // Sade Sati
        _ => 40,
    };

    // ── Rahu/Ketu transit favorability — the nodes don't have as precise or
    // universally-agreed a house-from-Moon table in classical sources as
    // Jupiter/Saturn do, so this leans on the broader "Upachaya house"
    // concept (3, 6, 10, 11 — where malefic/growth-type influences,
    // including the nodes, are classically said to improve over time)
    // rather than a specific nodal table.
    public static int NodeTransitScore(int houseFromMoon) =>
        houseFromMoon is 3 or 6 or 10 or 11 ? 75 : 40;
}

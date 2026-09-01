/// Classical Parashari dignity reference — exaltation/debilitation signs,
/// own signs, and planetary friendships (the same tables summarized in
/// Cosmic Foundations → 9 Planets). Sign order matches the backend's
/// VedicMath.SignNames: 0=Aries .. 11=Pisces.
library;

const List<String> kSignNames = [
  'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
  'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
];

/// Each sign's ruling planet (Rahu/Ketu have no rulership in the classical
/// system — Mars/Saturn keep their traditional rulerships of Scorpio and
/// Aquarius here rather than the modern outer-planet reassignment).
const List<String> kSignLord = [
  'Mars', 'Venus', 'Mercury', 'Moon', 'Sun', 'Mercury',
  'Venus', 'Mars', 'Jupiter', 'Saturn', 'Saturn', 'Jupiter',
];

const Map<String, int> kExaltationSign = {
  'Sun': 0, 'Moon': 1, 'Mars': 9, 'Mercury': 5,
  'Jupiter': 3, 'Venus': 11, 'Saturn': 6, 'Rahu': 1, 'Ketu': 7,
};

const Map<String, int> kDebilitationSign = {
  'Sun': 6, 'Moon': 7, 'Mars': 3, 'Mercury': 11,
  'Jupiter': 9, 'Venus': 5, 'Saturn': 0, 'Rahu': 7, 'Ketu': 1,
};

const Map<String, List<int>> kOwnSigns = {
  'Sun': [4],
  'Moon': [3],
  'Mars': [0, 7],
  'Mercury': [2, 5],
  'Jupiter': [8, 11],
  'Venus': [1, 6],
  'Saturn': [9, 10],
};

const Map<String, List<String>> kFriends = {
  'Sun': ['Moon', 'Mars', 'Jupiter'],
  'Moon': ['Sun', 'Mercury'],
  'Mars': ['Sun', 'Moon', 'Jupiter'],
  'Mercury': ['Sun', 'Venus'],
  'Jupiter': ['Sun', 'Moon', 'Mars'],
  'Venus': ['Mercury', 'Saturn'],
  'Saturn': ['Mercury', 'Venus'],
};

const Map<String, List<String>> kEnemies = {
  'Sun': ['Venus', 'Saturn'],
  'Moon': [],
  'Mars': ['Mercury'],
  'Mercury': ['Moon'],
  'Jupiter': ['Mercury', 'Venus'],
  'Venus': ['Sun', 'Moon'],
  'Saturn': ['Sun', 'Moon', 'Mars'],
};

/// One planet's classical dignity in the sign it currently occupies.
class Dignity {
  const Dignity(this.label, this.strength);
  final String label;
  final double strength; // 0..1, a broad-strokes sign-level indicator —
  // not full Shadbala (Sthana/Dig/Kala/Cheshta/Naisargika/Drik Bala), which
  // needs house/time/aspect data this simplified read doesn't attempt.
}

Dignity classicalDignity(String planet, int signIndex) {
  if (kExaltationSign[planet] == signIndex) return const Dignity('Exalted', 1.0);
  if (kDebilitationSign[planet] == signIndex) return const Dignity('Debilitated', 0.15);
  if (kOwnSigns[planet]?.contains(signIndex) ?? false) {
    return const Dignity('Own Sign', 0.85);
  }
  final lord = kSignLord[signIndex];
  if (lord == planet) return const Dignity('Own Sign', 0.85);
  if (kFriends[planet]?.contains(lord) ?? false) {
    return const Dignity('Friendly Sign', 0.65);
  }
  if (kEnemies[planet]?.contains(lord) ?? false) {
    return const Dignity('Enemy Sign', 0.35);
  }
  return const Dignity('Neutral Sign', 0.5);
}

/// Short keyword traits per graha, used to compose plain-language Dasha
/// narratives (e.g. "blends Venus's grace with Mercury's wit") — the same
/// domains summarized in Cosmic Foundations → 9 Planets.
const Map<String, String> kGrahaKeyword = {
  'Sun': 'authority and vitality',
  'Moon': 'emotion and intuition',
  'Mars': 'drive and courage',
  'Mercury': 'intellect and communication',
  'Jupiter': 'wisdom and growth',
  'Venus': 'grace and connection',
  'Saturn': 'discipline and patience',
  'Rahu': 'ambition and reinvention',
  'Ketu': 'detachment and introspection',
};

const Map<String, String> kGrahaDomain = {
  'Sun': 'career and self-expression',
  'Moon': 'home, mind and emotional life',
  'Mars': 'action, energy and conflict',
  'Mercury': 'communication, trade and learning',
  'Jupiter': 'fortune, wisdom and expansion',
  'Venus': 'relationships, art and finances',
  'Saturn': 'responsibility, structure and long-term work',
  'Rahu': 'unconventional pursuits and worldly ambition',
  'Ketu': 'inner life, release and spiritual insight',
};

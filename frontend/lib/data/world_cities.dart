import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// One real-world city: display name, state/region, country, and the
/// lat/lng/timezone an astrological chart needs. Backed by a bundled
/// GeoNames extract (cities15000 — every populated place with 15,000+
/// people, ~34,000 worldwide) — no Google Places API key required, no
/// network call at runtime.
class CityEntry {
  const CityEntry({
    required this.name,
    required this.state,
    required this.country,
    required this.lat,
    required this.lng,
    required this.timezone,
  });

  final String name;
  final String state;
  final String country;
  final double lat;
  final double lng;
  final String timezone;

  String get displayName =>
      [name, if (state.isNotEmpty) state, country].join(', ');
}

/// Lazily loads and caches the bundled world-cities dataset.
class WorldCities {
  WorldCities._();

  static List<CityEntry>? _cache;
  static Future<List<CityEntry>>? _loading;

  static Future<List<CityEntry>> load() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _loading ??= _load();
  }

  static Future<List<CityEntry>> _load() async {
    final raw = await rootBundle.loadString('assets/data/world_cities.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    // Rows are [name, state, country, lat, lng, timezone, population],
    // pre-sorted by population descending, so filtering preserves relevance
    // without any extra sort at runtime.
    final list = decoded.map((row) {
      final r = row as List<dynamic>;
      return CityEntry(
        name: r[0] as String,
        state: r[1] as String,
        country: r[2] as String,
        lat: (r[3] as num).toDouble(),
        lng: (r[4] as num).toDouble(),
        timezone: r[5] as String,
      );
    }).toList(growable: false);
    _cache = list;
    return list;
  }

  /// Cities whose name, state, or country matches [query]. Name-prefix
  /// matches rank above other-field matches; population order (the
  /// dataset's own order) is preserved within each group.
  static List<CityEntry> search(List<CityEntry> all, String query,
      {int limit = 40}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final prefixMatches = <CityEntry>[];
    final otherMatches = <CityEntry>[];
    for (final city in all) {
      final name = city.name.toLowerCase();
      if (name.startsWith(q)) {
        prefixMatches.add(city);
      } else if (name.contains(q) ||
          city.state.toLowerCase().contains(q) ||
          city.country.toLowerCase().contains(q)) {
        otherMatches.add(city);
      }
    }
    return [...prefixMatches, ...otherMatches].take(limit).toList();
  }
}

import 'api_client.dart';

/// Typed wrapper over GET /panchang/today. Wire shape verified directly
/// against the running backend — camelCase throughout, e.g.
/// { date, paksha, tithi: {name, endsAt}, nakshatra: {...}, yoga: {...},
///   karana: {...}, rahuKaal: {start, end}, yamaganda: {...}, gulika: {...},
///   abhijit: {...}, sunrise, sunset, moonrise, moonset }. All time fields
/// are ISO-8601 UTC with a trailing 'Z' (computed fresh each call, not
/// round-tripped through MySQL, so — unlike some other endpoints — these
/// don't need the "reinterpret as UTC" workaround).
class PanchangApi {
  PanchangApi._();

  static Future<Map<String, dynamic>> getToday() async =>
      await ApiClient.get('/panchang/today') as Map<String, dynamic>;
}

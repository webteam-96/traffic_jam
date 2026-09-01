import 'api_client.dart';

/// Typed wrapper over GET /signal/today. Wire shape — camelCase throughout:
/// { score, band: "green"|"yellow"|"red", label, guidance,
///   breakdown: { moonTransit: {score, driver}, panchang: {...},
///                dasha: {...}, transits: {...} },
///   weights: { moonTransit, panchang, dasha, transits } } (0..1 fractions).
class SignalApi {
  SignalApi._();

  /// [date] defaults to today (server-side, in the user's own timezone).
  /// Passing another date reuses the same scoring for that day — e.g. a
  /// week-ahead forecast — since the endpoint accepts an optional `date`
  /// query param.
  static Future<Map<String, dynamic>> getToday({DateTime? date}) async {
    final path = date == null
        ? '/signal/today'
        : '/signal/today?date=${_isoDate(date)}';
    return await ApiClient.get(path) as Map<String, dynamic>;
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

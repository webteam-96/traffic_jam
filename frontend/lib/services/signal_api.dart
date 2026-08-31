import 'api_client.dart';

/// Typed wrapper over GET /signal/today. Wire shape — camelCase throughout:
/// { score, band: "green"|"yellow"|"red", label, guidance,
///   breakdown: { moonTransit: {score, driver}, panchang: {...},
///                dasha: {...}, transits: {...} },
///   weights: { moonTransit, panchang, dasha, transits } } (0..1 fractions).
class SignalApi {
  SignalApi._();

  static Future<Map<String, dynamic>> getToday() async =>
      await ApiClient.get('/signal/today') as Map<String, dynamic>;
}

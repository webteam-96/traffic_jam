import 'api_client.dart';

/// Typed wrapper over GET /transits/upcoming. Wire shape — camelCase, a
/// plain array: [{planet, fromSign, toSign, date, houseFromMoon,
/// houseFromLagna}], sorted soonest-first. `date` is "yyyy-MM-dd" (no time
/// component — an ingress is a whole-day event, not a precise instant).
class TransitApi {
  TransitApi._();

  static Future<List<Map<String, dynamic>>> getUpcoming() async {
    final data = await ApiClient.get('/transits/upcoming') as List;
    return data.cast<Map<String, dynamic>>();
  }
}

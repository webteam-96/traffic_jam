import 'api_client.dart';

/// Typed wrapper over GET /remedies. Wire shape — camelCase array:
/// [{id, type, title, detail, audioUrl}], general-purpose remedies first,
/// then whatever matches the user's current Mahadasha/Antardasha lord.
class RemedyApi {
  RemedyApi._();

  static Future<List<Map<String, dynamic>>> getRemedies() async {
    final data = await ApiClient.get('/remedies') as List;
    return data.cast<Map<String, dynamic>>();
  }
}

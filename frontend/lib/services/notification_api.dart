import 'api_client.dart';

/// Typed wrapper over the Notification Service inbox endpoints. Wire shape
/// verified against the real backend: {id, type, title, body, source, at,
/// read} — source is lowercase "system"/"team".
class NotificationApi {
  NotificationApi._();

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final data = await ApiClient.get('/notifications') as List;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> markRead(String id) =>
      ApiClient.post('/notifications/$id/read');

  static Future<void> markAllRead() => ApiClient.post('/notifications/read-all');
}

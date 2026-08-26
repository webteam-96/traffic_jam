import 'api_client.dart';

/// Typed wrapper over the User Service endpoints — /me/birth-data and
/// /me/notification-preferences. Screens work with plain Dart values; this
/// is the only place that knows the wire format (dob "yyyy-MM-dd", tob
/// "HH:mm:ss", verified against the real backend).
class UserApi {
  UserApi._();

  /// Null if the user hasn't saved birth data yet (backend returns 404).
  static Future<Map<String, dynamic>?> getBirthData() async {
    try {
      return await ApiClient.get('/me/birth-data') as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<void> saveBirthData({
    required String? name,
    required DateTime dob,
    required int? hour24,
    required int? minute,
    required bool unknownTime,
    required String place,
    required double lat,
    required double lng,
    required String timezone,
  }) {
    return ApiClient.put('/me/birth-data', body: {
      'name': name,
      'dob': _isoDate(dob),
      'tob': unknownTime || hour24 == null || minute == null
          ? null
          : '${_pad(hour24)}:${_pad(minute)}:00',
      'unknownTime': unknownTime,
      'place': place,
      'lat': lat,
      'lng': lng,
      'timezone': timezone,
    });
  }

  static Future<Map<String, dynamic>> getNotificationPrefs() async =>
      await ApiClient.get('/me/notification-preferences') as Map<String, dynamic>;

  static Future<void> saveNotificationPrefs({
    required bool morning,
    required bool rahuKaal,
    required bool events,
    required bool dasha,
    required bool remedies,
    required Map<String, List<String>> channels,
  }) {
    return ApiClient.put('/me/notification-preferences', body: {
      'morning': morning,
      'rahuKaal': rahuKaal,
      'events': events,
      'dasha': dasha,
      'remedies': remedies,
      'channels': channels,
    });
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_pad(d.month)}-${_pad(d.day)}';

  static String _pad(int v) => v.toString().padLeft(2, '0');
}

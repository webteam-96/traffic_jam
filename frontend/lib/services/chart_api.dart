import 'api_client.dart';

/// Typed wrapper over GET /chart and GET /dasha. Wire shapes — camelCase:
///
/// /chart:
/// { ayanamsa, nakshatra, computedAt,
///   ascendant: {tropicalLongitude, siderealLongitude, signIndex, sign, known},
///   d1: [{planet, signIndex, sign, degreeInSign, house, retrograde}] (house set),
///   d9/d10/d60: same shape but house is always null (no varga-Lagna computed),
///   moonChart: same shape, house is house-from-Moon,
///   kp: [{planet, signIndex, sign, degreeInSign, lordship:{signLord,starLord,
///        subLord,subSubLord}, house}] — [] when birth time isn't known exactly,
///   cusps: [{house, signIndex, sign, degreeInSign, lordship:{...}, planets:[str]}]
///        — [] under the same condition as kp }
/// computedAt round-trips through a MySQL DATETIME column and needs the
/// "reinterpret as UTC" treatment; every other timestamp in these two
/// endpoints is embedded JSON text and already carries its own 'Z'.
///
/// /dasha:
/// { validMonth, maha: [{lord, start, end, current}], antar: [...], pratyantar: [...] }
class ChartApi {
  ChartApi._();

  static Future<Map<String, dynamic>> getChart() async =>
      await ApiClient.get('/chart') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> getDasha() async =>
      await ApiClient.get('/dasha') as Map<String, dynamic>;

  /// Stateless chart+Dasha computation for someone other than the signed-in
  /// user — "Get Kundli" for family/friends. Nothing is saved server-side;
  /// returns `{chart: {...}, dasha: {...}}` in the exact same shapes as
  /// [getChart]/[getDasha], computed fresh from the given birth details.
  static Future<Map<String, dynamic>> compute({
    required DateTime dob,
    required int? hour24,
    required int? minute,
    required bool unknownTime,
    required double lat,
    required double lng,
    required String timezone,
  }) async {
    final result = await ApiClient.post('/chart/compute', body: {
      'dob': '${dob.year.toString().padLeft(4, '0')}-'
          '${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}',
      'tob': unknownTime || hour24 == null || minute == null
          ? null
          : '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00',
      'unknownTime': unknownTime,
      'lat': lat,
      'lng': lng,
      'timezone': timezone,
    }) as Map<String, dynamic>;
    return result;
  }
}

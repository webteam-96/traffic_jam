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
}

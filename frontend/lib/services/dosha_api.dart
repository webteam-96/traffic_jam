import 'api_client.dart';

/// Typed wrapper over GET /doshas. Wire shape — camelCase:
/// { mangal: {fromLagna, houseFromLagna, fromMoon, houseFromMoon, fromVenus,
///            houseFromVenus, marsInOwnOrExaltedSign},
///   kaalSarp: {isPresent, subType, rahuHouseFromLagna},
///   sadeSati: {isActive, phase, phaseStartedOn, phaseEndsOn, fullCycleEndsOn} }
/// `fromLagna`/`houseFromLagna` are null when birth time is unknown.
/// Pitra Dosha is deliberately not included — see DoshaEndpoints.cs.
class DoshaApi {
  DoshaApi._();

  static Future<Map<String, dynamic>> getDoshas() async =>
      await ApiClient.get('/doshas') as Map<String, dynamic>;
}

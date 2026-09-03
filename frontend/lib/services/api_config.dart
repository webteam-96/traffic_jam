import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'dart:io' show Platform;

/// Backend base URL, resolved per-platform since "localhost" means different
/// things depending on where the app is actually running.
class ApiConfig {
  ApiConfig._();

  // Physical devices can't reach "localhost" (that's the device itself) —
  // pass the dev machine's LAN IP explicitly, e.g.:
  //   flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.44:5227/api/v1
  static const _override = String.fromEnvironment('API_BASE_URL');

  // The deployed backend's real URL — note the doubled "api": a reverse
  // proxy in front of the app adds its own "/api" on top of this app's own
  // "/api/v1" route prefix. Every call elsewhere in the app uses a path like
  // "/auth/session", so this is the entire prefix that needs to precede it.
  // Single source of truth for this app — must match
  // backend/src/TrafficJam.Api/appsettings.Production.json's Api:PublicBaseUrl
  // and admin/.env.production's VITE_API_BASE_URL if this deployment's domain
  // or proxy path ever changes.
  static const _productionUrl = 'https://trafficjam-live.kaizeninfotech.com/api/api/v1';

  // Local dev backend port — must match `applicationUrl` in
  // backend/src/TrafficJam.Api/Properties/launchSettings.json and
  // appsettings.Development.json's Api:PublicBaseUrl. Named once here rather
  // than repeated as a literal in each platform branch below.
  static const _localDevPort = 5227;

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // Release builds (and anyone who forgets --dart-define) hit the real
    // deployed backend by default; `flutter run` debug builds keep hitting
    // a local backend so day-to-day development is unaffected.
    if (kReleaseMode) return _productionUrl;
    if (kIsWeb) return 'http://localhost:$_localDevPort';
    // Android emulator's loopback to the host machine is 10.0.2.2, not localhost.
    if (Platform.isAndroid) return 'http://10.0.2.2:$_localDevPort';
    return 'http://localhost:$_localDevPort'; // iOS simulator, macOS
  }
}

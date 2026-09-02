import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'dart:io' show Platform;

/// Backend base URL, resolved per-platform since "localhost" means different
/// things depending on where the app is actually running.
class ApiConfig {
  ApiConfig._();

  // Physical devices can't reach "localhost" (that's the device itself) —
  // pass the dev machine's LAN IP explicitly, e.g.:
  //   flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.44:5080
  static const _override = String.fromEnvironment('API_BASE_URL');

  // The deployed backend's real URL — note the doubled "api": a reverse
  // proxy in front of the app adds its own "/api" on top of this app's own
  // "/api/v1" route prefix. Every call elsewhere in the app uses a path like
  // "/auth/session", so this is the entire prefix that needs to precede it.
  static const _productionUrl = 'https://trafficjam-live.kaizeninfotech.com/api/api/v1';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // Release builds (and anyone who forgets --dart-define) hit the real
    // deployed backend by default; `flutter run` debug builds keep hitting
    // a local backend so day-to-day development is unaffected.
    if (kReleaseMode) return _productionUrl;
    if (kIsWeb) return 'http://localhost:5080';
    // Android emulator's loopback to the host machine is 10.0.2.2, not localhost.
    if (Platform.isAndroid) return 'http://10.0.2.2:5080';
    return 'http://localhost:5080'; // iOS simulator, macOS
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Backend base URL, resolved per-platform since "localhost" means different
/// things depending on where the app is actually running.
class ApiConfig {
  ApiConfig._();

  // Physical devices can't reach "localhost" (that's the device itself) —
  // pass the dev machine's LAN IP explicitly, e.g.:
  //   flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.44:5080
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:5080';
    // Android emulator's loopback to the host machine is 10.0.2.2, not localhost.
    if (Platform.isAndroid) return 'http://10.0.2.2:5080';
    return 'http://localhost:5080'; // iOS simulator, macOS
  }
}

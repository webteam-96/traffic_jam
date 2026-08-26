import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Backend base URL, resolved per-platform since "localhost" means different
/// things depending on where the app is actually running.
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5080';
    // Android emulator's loopback to the host machine is 10.0.2.2, not localhost.
    if (Platform.isAndroid) return 'http://10.0.2.2:5080';
    return 'http://localhost:5080'; // iOS simulator, macOS, physical devices on the same network
  }
}

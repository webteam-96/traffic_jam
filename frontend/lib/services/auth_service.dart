import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthState {
  const AuthState({required this.status, this.onboardingComplete = false, this.name});
  final AuthStatus status;
  final bool onboardingComplete;
  final String? name;
}

/// App-wide session state — ValueNotifier singleton, same lightweight
/// pattern as KundliStore. Backed by real tokens from the backend's
/// `/auth/dev-login` (fixed OTP "123456", any phone number) until a real
/// Firebase project replaces it — see backend/README.md.
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'tj_access_token';
  static const _refreshKey = 'tj_refresh_token';

  static String? _accessToken;
  static String? _refreshToken;

  static final ValueNotifier<AuthState> state =
      ValueNotifier(const AuthState(status: AuthStatus.unknown));

  /// Call once at app start, before the first API call.
  static void init() {
    ApiClient.configure(
      accessTokenProvider: () async => _accessToken,
      refreshHandler: _tryRefresh,
    );
  }

  /// Restores a stored session if one exists and is still valid. Leaves
  /// [state] as loggedOut otherwise — always resolves, never throws.
  static Future<void> restoreSession() async {
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);

    if (_accessToken == null || _refreshToken == null) {
      state.value = const AuthState(status: AuthStatus.loggedOut);
      return;
    }

    try {
      await _refreshMeIntoState();
    } catch (_) {
      await _clearTokens();
      state.value = const AuthState(status: AuthStatus.loggedOut);
    }
  }

  /// Dev-mode login — fixed OTP, any phone number. Throws [ApiException] on
  /// failure (e.g. wrong OTP, or dev mode disabled server-side).
  static Future<void> loginWithDevOtp(String phoneNumber, String otp) async {
    final result = await ApiClient.post(
      '/auth/dev-login',
      body: {'phoneNumber': phoneNumber, 'otp': otp},
      auth: false,
    ) as Map<String, dynamic>;

    await _storeTokens(result['accessToken'] as String, result['refreshToken'] as String);
    await _refreshMeIntoState();
  }

  static Future<void> logout() async {
    await _clearTokens();
    state.value = const AuthState(status: AuthStatus.loggedOut);
  }

  static Future<void> _refreshMeIntoState() async {
    final me = await ApiClient.get('/me') as Map<String, dynamic>;
    state.value = AuthState(
      status: AuthStatus.loggedIn,
      onboardingComplete: me['onboardingComplete'] == true,
      name: me['name'] as String?,
    );
  }

  static Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final result = await ApiClient.post(
        '/auth/refresh',
        body: {'refreshToken': _refreshToken},
        auth: false,
      ) as Map<String, dynamic>;
      await _storeTokens(result['accessToken'] as String, result['refreshToken'] as String);
      return true;
    } catch (_) {
      await _clearTokens();
      state.value = const AuthState(status: AuthStatus.loggedOut);
      return false;
    }
  }

  static Future<void> _storeTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  static Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthState {
  const AuthState({
    required this.status,
    this.onboardingComplete = false,
    this.name,
    this.phoneNumber,
  });
  final AuthStatus status;
  final bool onboardingComplete;
  final String? name;

  /// The E.164 number this session signed in with, e.g. "+919876543210".
  /// Null only for a session stored before this was kept — see
  /// [AuthService.restoreSession].
  final String? phoneNumber;
}

/// App-wide session state — ValueNotifier singleton, same lightweight
/// pattern as KundliStore. Backed by real tokens from the backend's
/// `/auth/dev-login`, which accepts a fixed code per number until a real
/// Firebase project replaces it — see AuthEndpoints.cs and
/// backend/README.md. The app doesn't know or care which code applies; it
/// posts whatever was typed and the server decides.
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'tj_access_token';
  static const _refreshKey = 'tj_refresh_token';
  static const _phoneKey = 'tj_phone_number';

  static String? _accessToken;
  static String? _refreshToken;
  static String? _phoneNumber;

  /// The signed-in number, or null when signed out. Kept in secure storage
  /// beside the tokens rather than SharedPreferences: it identifies the
  /// person, and the backend treats it as personal data (encrypted at rest,
  /// see User.Phone), so the app shouldn't hold it somewhere weaker.
  ///
  /// The server never returns it — GET /me carries no phone number — so the
  /// only moment the app can capture it is the sign-in that used it.
  static String? get phoneNumber => _phoneNumber;

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
    // Null for anyone already signed in before this was stored; their number
    // fills in the next time they sign in, and nothing depends on it being
    // present.
    _phoneNumber = await _storage.read(key: _phoneKey);

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
    _phoneNumber = phoneNumber;
    await _storage.write(key: _phoneKey, value: phoneNumber);
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
      phoneNumber: _phoneNumber,
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
    _phoneNumber = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    // Cleared with the tokens, not left behind: signing out has to leave no
    // trace of who was signed in, and this is the only identifying value the
    // app stores.
    await _storage.delete(key: _phoneKey);
  }
}

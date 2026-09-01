import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Thin JSON HTTP client. Doesn't know about [AuthService] directly (that
/// would be a circular import) — [AuthService.init] wires in the token
/// provider and refresh handler via [configure] at app start.
class ApiClient {
  ApiClient._();

  static Future<String?> Function()? _accessTokenProvider;
  static Future<bool> Function()? _refreshHandler;

  static void configure({
    required Future<String?> Function() accessTokenProvider,
    required Future<bool> Function() refreshHandler,
  }) {
    _accessTokenProvider = accessTokenProvider;
    _refreshHandler = refreshHandler;
  }

  static Future<dynamic> get(String path, {bool auth = true}) =>
      _send('GET', path, auth: auth);
  static Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);
  static Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send('PUT', path, body: body, auth: auth);
  static Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);
  static Future<dynamic> delete(String path, {Object? body, bool auth = true}) =>
      _send('DELETE', path, body: body, auth: auth);

  static Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    bool isRetryAfterRefresh = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _accessTokenProvider?.call();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final encodedBody = body == null ? null : jsonEncode(body);

    final response = await switch (method) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: encodedBody),
      'PUT' => http.put(uri, headers: headers, body: encodedBody),
      'PATCH' => http.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => http.delete(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError('Unsupported method $method'),
    };

    // One retry after a silent token refresh — avoids surfacing a 401 to the
    // UI just because the access token happened to expire mid-session.
    if (response.statusCode == 401 &&
        auth &&
        !isRetryAfterRefresh &&
        _refreshHandler != null) {
      final refreshed = await _refreshHandler!.call();
      if (refreshed) {
        return _send(method, path, body: body, auth: auth, isRetryAfterRefresh: true);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    var code = 'UNKNOWN';
    var message = response.body.isEmpty ? response.reasonPhrase ?? 'Request failed' : response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        code = decoded['error']['code'] as String? ?? code;
        message = decoded['error']['message'] as String? ?? message;
      }
    } catch (_) {
      // Response wasn't JSON — keep the raw body as the message.
    }

    throw ApiException(response.statusCode, code, message);
  }
}

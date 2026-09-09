import 'api_client.dart';

/// Typed wrapper over the astrologer endpoints — the About Jay screen's
/// content, which the team edits in the admin panel, plus the review a user
/// can submit about Jay.
class AstrologerApi {
  AstrologerApi._();

  static Future<Map<String, dynamic>> getProfile() async =>
      await ApiClient.get('/astrologer') as Map<String, dynamic>;

  /// The caller's own review, or null if they haven't written one. A submitted
  /// review is invisible to everyone else until the team approves it, so the
  /// screen needs this to show its status rather than looking like the
  /// submission went nowhere.
  static Future<Map<String, dynamic>?> getMyReview() async {
    final result = await ApiClient.get('/reviews/mine');
    return result is Map<String, dynamic> ? result : null;
  }

  static Future<void> submitReview({
    required String quote,
    required int rating,
  }) =>
      ApiClient.post('/reviews', body: {'quote': quote, 'rating': rating});
}

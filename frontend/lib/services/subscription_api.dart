import 'api_client.dart';

/// Typed wrapper over the Subscription Service endpoints. Checkout returns
/// a 503 PAYMENTS_NOT_CONFIGURED until a payment gateway is wired up — the
/// caller is expected to surface that as a friendly message, not a crash.
class SubscriptionApi {
  SubscriptionApi._();

  static Future<List<Map<String, dynamic>>> getPlans() async {
    final data = await ApiClient.get('/subscription/plans', auth: false) as List;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getSubscription() async =>
      await ApiClient.get('/subscription') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> checkout(String planId) async =>
      await ApiClient.post('/subscription/checkout', body: {'planId': planId})
          as Map<String, dynamic>;
}

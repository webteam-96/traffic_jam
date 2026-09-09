import 'api_client.dart';

/// Typed wrapper over the Consultation Service endpoints — Ask Jay questions
/// and their message threads. Wire shapes verified against the real backend.
class ConsultApi {
  ConsultApi._();

  static Future<List<Map<String, dynamic>>> getPlans() async {
    final data = await ApiClient.get('/consult/plans', auth: false) as List;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> askQuestion({
    required String domain,
    required String question,
    required String planId,
  }) async {
    return await ApiClient.post('/consult/questions', body: {
      'domain': domain,
      'question': question,
      'planId': planId,
    }) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getQuestions() async {
    final data = await ApiClient.get('/consult/questions') as List;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getMessages(String questionId) async {
    final data =
        await ApiClient.get('/consult/questions/$questionId/messages') as List;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> sendMessage(
      String questionId, String text) async {
    return await ApiClient.post(
      '/consult/questions/$questionId/messages',
      body: {'text': text},
    ) as Map<String, dynamic>;
  }

  /// The slots the astrologer has published and nobody has taken. UTC — the
  /// screen renders them in the reader's own zone.
  static Future<List<Map<String, dynamic>>> getAppointmentSlots() async {
    final data = await ApiClient.get('/consult/appointments/slots') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Books a consultation — POST /consult/appointments. Returns
  /// `{appointmentId, reference, status}`.
  ///
  /// Pass [slotId] to take a published slot, which is confirmed on the spot.
  /// Omit it to ask for a time of the user's own choosing, which stays Pending
  /// until the astrologer agrees.
  static Future<Map<String, dynamic>> bookAppointment({
    required String area,
    required String email,
    required String? message,
    required DateTime preferredDate,
    required int preferredHour24,
    required int preferredMinute,
    String? slotId,
    String? timezone,
  }) async {
    return await ApiClient.post('/consult/appointments', body: {
      'area': area,
      'email': email,
      'message': message,
      'preferredDate': '${preferredDate.year.toString().padLeft(4, '0')}-'
          '${preferredDate.month.toString().padLeft(2, '0')}-'
          '${preferredDate.day.toString().padLeft(2, '0')}',
      'preferredTime': '${preferredHour24.toString().padLeft(2, '0')}:'
          '${preferredMinute.toString().padLeft(2, '0')}:00',
      'slotId': ?slotId,
      'timezone': ?timezone,
    }) as Map<String, dynamic>;
  }
}

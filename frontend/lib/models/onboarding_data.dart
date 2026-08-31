/// In-memory scratchpad shared across the onboarding flow's 4 pushed screens
/// (Identity → Birth Time → Birth Place → Consent → Calculating), same
/// lightweight static-singleton pattern as [AuthService.state]/[KundliStore].
/// [CalculatingScreen] reads it to call `UserApi.saveBirthData` once consent
/// is given, then [reset]s it. [WelcomeScreen] also calls [reset] before
/// starting a fresh run, so a previous incomplete attempt never leaks in.
class OnboardingData {
  OnboardingData._();

  static String? name;
  static DateTime? dob;
  static int hour = 4; // 1..12
  static int minute = 42;
  static bool isAm = true;
  static bool unknownTime = false;
  static String? place;
  static double? lat;
  static double? lng;
  static String? timezone;

  static void reset() {
    name = null;
    dob = null;
    hour = 4;
    minute = 42;
    isAm = true;
    unknownTime = false;
    place = null;
    lat = null;
    lng = null;
    timezone = null;
  }
}

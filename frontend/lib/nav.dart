import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';
import 'services/auth_service.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/identity_screen.dart';
import 'screens/onboarding/birth_time_screen.dart';
import 'screens/onboarding/birth_place_screen.dart';
import 'screens/onboarding/consent_screen.dart';
import 'screens/onboarding/calculating_screen.dart';
import 'screens/details/traffic_signal_screen.dart';
import 'screens/details/time_windows_screen.dart';
import 'screens/details/vibe_meter_screen.dart';
import 'screens/details/color_of_day_screen.dart';
import 'screens/details/astro_insights_screen.dart';
import 'screens/kundli/kundli_landing_screen.dart';
import 'screens/details/dasha_timeline_screen.dart';
import 'screens/details/planet_strengths_screen.dart';
import 'screens/details/upcoming_transits_screen.dart';
import 'screens/ask/chat_screen.dart';
import 'screens/ask/my_questions_screen.dart';
import 'screens/remedies/remedies_screen.dart';
import 'screens/profile/edit_birth_data_screen.dart';
import 'screens/profile/notification_prefs_screen.dart';
import 'screens/profile/subscription_screen.dart';
import 'screens/profile/book_appointment_screen.dart';
import 'screens/profile/about_jay_kotecha_screen.dart';
import 'screens/profile/privacy_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/cosmic_foundations/cosmic_foundations_screen.dart';
import 'screens/cosmic_foundations/zodiac_signs_screen.dart';
import 'screens/cosmic_foundations/planets_screen.dart';
import 'screens/cosmic_foundations/houses_screen.dart';
import 'screens/cosmic_foundations/elements_screen.dart';
import 'screens/cosmic_foundations/nakshatras_screen.dart';
import 'screens/cosmic_foundations/yog_screen.dart';

typedef ScreenBuilder = Widget Function();

class NavDest {
  const NavDest(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final ScreenBuilder builder;
}

class NavGroup {
  const NavGroup(this.title, this.items);
  final String title;
  final List<NavDest> items;
}

/// Every pushed screen, grouped — powers the hamburger nav hub so the whole
/// app is reachable. In-context taps (home actions, profile rows) push these too.
const List<NavGroup> kNavGroups = [
  NavGroup('Daily Insights', [
    NavDest("Today's Signal", Icons.traffic_outlined, TrafficSignalScreen.new),
    NavDest('Auspicious Windows', Icons.timelapse, TimeWindowsScreen.new),
    NavDest('Vibe Meter', Icons.speed, VibeMeterScreen.new),
    NavDest('Color of the Day', Icons.palette_outlined, ColorOfDayScreen.new),
    NavDest('Astro Insights', Icons.insights, AstroInsightsScreen.new),
    NavDest('Upcoming Transits', Icons.calendar_month, UpcomingTransitsScreen.new),
  ]),
  NavGroup('My Chart', [
    NavDest('Kundli', Icons.grid_4x4, KundliLandingScreen.new),
    NavDest('Dasha Timeline', Icons.timeline, DashaTimelineScreen.new),
    NavDest('Planet Strengths', Icons.bar_chart, PlanetStrengthsScreen.new),
  ]),
  NavGroup('Ask Jay', [
    NavDest('My Questions', Icons.history, MyQuestionsScreen.new),
  ]),
  NavGroup('Remedies', [
    NavDest('Remedies', Icons.spa_outlined, RemediesScreen.new),
  ]),
  NavGroup('Account', [
    NavDest('Notifications', Icons.notifications_none, NotificationsScreen.new),
    NavDest('Edit Birth Data', Icons.edit_outlined, EditBirthDataScreen.new),
    NavDest('Notification Prefs', Icons.tune, NotificationPrefsScreen.new),
    NavDest('Subscription', Icons.workspace_premium_outlined, SubscriptionScreen.new),
    NavDest('Book Appointment', Icons.calendar_month, BookAppointmentScreen.new),
    NavDest('About Jay Kotecha', Icons.person_outline, AboutJayKotechaScreen.new),
    NavDest('Privacy', Icons.shield_outlined, PrivacyScreen.new),
  ]),
  NavGroup('Cosmic Foundations', [
    NavDest('12 Zodiac Signs', Icons.auto_awesome, ZodiacSignsScreen.new),
    NavDest('9 Planets', Icons.brightness_7, PlanetsScreen.new),
    NavDest('12 Houses', Icons.grid_3x3, HousesScreen.new),
    NavDest('5 Elements', Icons.diamond, ElementsScreen.new),
    NavDest('27 Nakshatras', Icons.nightlight_round, NakshatrasScreen.new),
    NavDest('Yog in Astrology', Icons.auto_awesome_motion, YogScreen.new),
  ]),
];

void pushScreen(BuildContext context, ScreenBuilder builder) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder()));
}

/// Lightweight confirmation for terminal actions (save, upgrade, share…).
void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: AppText.sans(size: 14, color: AppColors.textPrimary)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceRaised2,
      duration: const Duration(seconds: 2),
    ));
}

/// Enter the main app, clearing the onboarding/auth stack (end of onboarding).
void goToShell(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AppShell()),
    (route) => false,
  );
}

/// Jump into the main shell on the Ask Jay tab (clears the stack) — used by
/// "Ask Jay" CTAs on other screens, since composing a question needs the
/// full Ask Jay form, not a specific chat thread.
void goToAskJayTab(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 3)),
    (route) => false,
  );
}

/// Return to the login screen, clearing the stack (log out).
void goToLogin(BuildContext context) {
  unawaited(AuthService.logout());
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

/// After a successful OTP verify — AuthService.state has already flipped to
/// loggedIn. Explicitly lands on Welcome (onboarding incomplete) or the main
/// Shell, clearing the stack, rather than popping back to "first" and
/// trusting main.dart's _RootGate is still mounted underneath to react to
/// the new auth state — it isn't, once the user has ever signed out
/// (goToLogin, above) or finished onboarding (goToShell, below), both of
/// which already replace the entire stack with a screen that isn't
/// _RootGate. Without this, verifying OTP after a sign-out just re-reveals
/// goToLogin's own static LoginScreen instead of continuing in.
void goToPostLogin(BuildContext context) {
  final onboardingComplete = AuthService.state.value.onboardingComplete;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => onboardingComplete ? const AppShell() : const WelcomeScreen()),
    (route) => false,
  );
}

// ── Named flow hops (so each screen imports only nav.dart) ───────────────────
// Onboarding / auth chain
void goToOtp(BuildContext c, {String phoneNumber = ''}) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phoneNumber)));
void goToWelcome(BuildContext c) => pushScreen(c, WelcomeScreen.new);
void goToIdentity(BuildContext c) => pushScreen(c, IdentityScreen.new);
void goToBirthTime(BuildContext c) => pushScreen(c, BirthTimeScreen.new);
void goToBirthPlace(BuildContext c) => pushScreen(c, BirthPlaceScreen.new);
void goToConsent(BuildContext c) => pushScreen(c, ConsentScreen.new);
void goToCalculating(BuildContext c) => pushScreen(c, CalculatingScreen.new);
// Profile / account deep-links
void goToEditBirthData(BuildContext c) => pushScreen(c, EditBirthDataScreen.new);
void goToNotificationPrefs(BuildContext c) => pushScreen(c, NotificationPrefsScreen.new);
void goToSubscription(BuildContext c) => pushScreen(c, SubscriptionScreen.new);
void goToNotifications(BuildContext c) => pushScreen(c, NotificationsScreen.new);
// Ask Jay
void goToChat(BuildContext c, {required String questionId}) =>
    Navigator.of(c).push(MaterialPageRoute(
        builder: (_) => AskChatScreen(questionId: questionId)));
void goToMyQuestions(BuildContext c) => pushScreen(c, MyQuestionsScreen.new);
// My Chart sub-views
void goToKundli(BuildContext c) => pushScreen(c, KundliLandingScreen.new);
void goToDashaTimeline(BuildContext c) => pushScreen(c, DashaTimelineScreen.new);
void goToPlanetStrengths(BuildContext c) => pushScreen(c, PlanetStrengthsScreen.new);
void goToAstroInsights(BuildContext c) => pushScreen(c, AstroInsightsScreen.new);
void goToUpcomingTransits(BuildContext c) => pushScreen(c, UpcomingTransitsScreen.new);
// Profile / account deep-links
void goToBookAppointment(BuildContext c) => pushScreen(c, BookAppointmentScreen.new);
void goToAboutJayKotecha(BuildContext c) => pushScreen(c, AboutJayKotechaScreen.new);
// Cosmic Foundations
void goToCosmicFoundations(BuildContext c) => pushScreen(c, CosmicFoundationsScreen.new);
void goToZodiacSigns(BuildContext c) => pushScreen(c, ZodiacSignsScreen.new);
void goToPlanets(BuildContext c) => pushScreen(c, PlanetsScreen.new);
void goToHouses(BuildContext c) => pushScreen(c, HousesScreen.new);
void goToElements(BuildContext c) => pushScreen(c, ElementsScreen.new);
void goToNakshatras(BuildContext c) => pushScreen(c, NakshatrasScreen.new);
void goToYog(BuildContext c) => pushScreen(c, YogScreen.new);

/// Slide-out navigation hub (opened from the top-bar hamburger).
class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgBottom,
      width: 300,
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.scaffoldGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Text('TRAFFIC JAM',
                        style: AppText.logoFont(size: 18, letterSpacing: 1.6)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('All screens',
                    style: AppText.sans(size: 12, color: AppColors.textMuted)),
              ),
              const Divider(color: AppColors.borderFaint, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final g in kNavGroups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        child: Text(g.title.toUpperCase(),
                            style: AppText.sectionLabel),
                      ),
                      for (final d in g.items)
                        ListTile(
                          dense: true,
                          leading: Icon(d.icon, color: AppColors.textTan, size: 20),
                          title: Text(d.label,
                              style: AppText.sans(
                                  size: 14, color: AppColors.textPrimary)),
                          onTap: () {
                            Navigator.of(context).pop(); // close drawer
                            pushScreen(context, d.builder);
                          },
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

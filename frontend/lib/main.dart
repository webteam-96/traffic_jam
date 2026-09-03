import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  AuthService.init();
  runApp(const TrafficJamApp());
}

class TrafficJamApp extends StatelessWidget {
  const TrafficJamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Jam',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _RootGate(),
    );
  }
}

/// Shows the splash while a stored session (if any) is checked against the
/// backend, then routes to Login / Welcome (onboarding) / the main app shell
/// accordingly — see AuthService.restoreSession.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  // Gates the splash independently of AuthService.state — otherwise the
  // ValueListenableBuilder below would react the instant restoreSession()
  // resolves, which can be near-instant and flash the splash off too fast.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      AuthService.restoreSession(),
      Future.delayed(const Duration(seconds: 4)),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();

    return ValueListenableBuilder<AuthState>(
      valueListenable: AuthService.state,
      builder: (context, auth, _) {
        return switch (auth.status) {
          AuthStatus.unknown => const SplashScreen(),
          AuthStatus.loggedOut => const LoginScreen(),
          AuthStatus.loggedIn =>
            auth.onboardingComplete ? const AppShell() : const WelcomeScreen(),
        };
      },
    );
  }
}

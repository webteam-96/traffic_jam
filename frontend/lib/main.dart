import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';
import 'screens/auth/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
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

/// Shows the splash briefly on launch, then reveals the main app shell.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return the screen straight from `home` so it inherits tight full-screen
    // constraints. (An AnimatedSwitcher's internal Stack was letting the splash
    // Scaffold shrink-wrap to its content — the half-width render.)
    return _ready ? const AppShell() : const SplashScreen();
  }
}

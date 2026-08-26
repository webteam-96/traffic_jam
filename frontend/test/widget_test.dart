import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_jam/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme tokens are defined', () {
    expect(AppColors.gold, isA<Color>());
    expect(buildAppTheme().scaffoldBackgroundColor, AppColors.bg);
  });
}

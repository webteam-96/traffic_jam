import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// Phone login. Hero serif heading, a frosted card with a +91 chip + phone
/// field, and OTP CTA plus Google/Apple outlined options. All mocked — no API.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text('Welcome', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sign in to receive your daily astro-signal.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          GlassCard(
            goldTopBorder: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Mobile Number'),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.goldBorderSoft),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+91',
                        style: AppText.sans(
                          size: 16,
                          weight: FontWeight.w600,
                          color: AppColors.textTan,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        cursorColor: AppColors.gold,
                        style: AppText.sans(
                          size: 16,
                          weight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.5,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '98765 43210',
                          hintStyle: AppText.sans(
                            size: 16,
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                          ),
                          filled: true,
                          fillColor: AppColors.bgDeep,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                            borderSide: const BorderSide(
                                color: AppColors.goldBorderSoft),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                            borderSide:
                                const BorderSide(color: AppColors.gold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'We will send a one-time password.',
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GoldButton(
            label: 'CONTINUE',
            icon: Icons.arrow_forward,
            onPressed: () => goToOtp(context),
          ),
          const SizedBox(height: AppSpacing.section),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.borderSoft)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('or continue with', style: AppText.microLabel),
              ),
              const Expanded(child: Divider(color: AppColors.borderSoft)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GoldButton(
            label: 'Google',
            icon: Icons.g_mobiledata,
            outlined: true,
            onPressed: () => goToOtp(context),
          ),
          const SizedBox(height: AppSpacing.md),
          GoldButton(
            label: 'Apple',
            icon: Icons.apple,
            outlined: true,
            onPressed: () => goToOtp(context),
          ),
        ],
      ),
    );
  }
}

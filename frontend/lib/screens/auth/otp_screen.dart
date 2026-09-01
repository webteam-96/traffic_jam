import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/services/auth_service.dart';
import 'package:traffic_jam/services/api_client.dart';

/// OTP verification (pushed). Six frosted digit boxes fed by one hidden field,
/// a live resend countdown, and the VERIFY CTA.
///
/// Wired to the backend's dev-mode login (`POST /auth/dev-login`) — a
/// stand-in for real Firebase phone-OTP until that's configured. The fixed
/// dev code is always "123456", any phone number.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, this.phoneNumber = ''});

  final String phoneNumber;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _len = 6;
  static const _resendSeconds = 28;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _remaining = _resendSeconds;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remaining = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _code => _controller.text;

  String get _timerLabel {
    final m = _remaining ~/ 60;
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    try {
      await AuthService.loginWithDevOtp('+91${widget.phoneNumber}', _code);
      if (!mounted) return;
      goToPostLogin(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      toast(context, e.code == 'INVALID_OTP' ? 'Incorrect code — try again.' : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _verifying = false);
      toast(context, "Couldn't reach the server — check your connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Verify',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          IconChip(
            size: 56,
            circular: true,
            glow: true,
            child: const Icon(Icons.sms_outlined,
                color: AppColors.gold, size: 26),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Verify your number', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the 6-digit code sent to +91 ${widget.phoneNumber}',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Dev mode — no real SMS is sent. Use code 123456.',
            style: AppText.bodySmall.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: AppSpacing.section),

          // Six boxes driven by one offstage TextField overlaid for taps.
          Stack(
            children: [
              Row(
                children: [
                  for (int i = 0; i < _len; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _digitBox(i)),
                  ],
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    showCursor: false,
                    keyboardType: TextInputType.number,
                    maxLength: _len,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          _resendRow(),
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: _verifying ? 'VERIFYING…' : 'VERIFY & CONTINUE',
            icon: Icons.check_circle_outline,
            onPressed: (_code.length == _len && !_verifying) ? _verify : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text('Wrong number? Go back and edit',
                style: AppText.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _digitBox(int i) {
    final filled = i < _code.length;
    final active = i == _code.length; // next box to fill
    return AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: active ? AppColors.gold : AppColors.borderFaint,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.25),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Text(
          filled ? _code[i] : '',
          style: AppText.serif(
            size: 24,
            weight: FontWeight.w700,
            color: AppColors.amber,
          ),
        ),
      ),
    );
  }

  Widget _resendRow() {
    final canResend = _remaining == 0;
    return Center(
      child: canResend
          ? GestureDetector(
              onTap: () {
                _controller.clear();
                _startTimer();
              },
              child: Text(
                'Resend code',
                style: AppText.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            )
          : Text('Resend in $_timerLabel', style: AppText.bodySmall),
    );
  }
}

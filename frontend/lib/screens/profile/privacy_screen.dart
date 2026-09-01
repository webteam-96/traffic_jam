import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/services/user_api.dart';
import 'package:traffic_jam/services/api_client.dart';

/// Privacy — Business Flow §12 step 7: export all data and delete account,
/// both wired to real endpoints (GET /me/export, DELETE /me). Consent
/// history isn't shown — no consent-log system exists in the backend yet
/// (would need its own entity + hooks into onboarding/notification-prefs),
/// so this deliberately doesn't fabricate dates for something that isn't
/// actually tracked.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final data = await UserApi.exportData();
      if (!mounted) return;
      _showExportSummary(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't reach the server — check your connection.");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showExportSummary(Map<String, dynamic> data) {
    final questions = (data['questions'] as List).length;
    final appointments = (data['appointments'] as List).length;
    final hasBirthData = data['birthData'] != null;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navBarBase,
        title: Text('Your data', style: AppText.serif(size: 18, color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile: ${data['profile']['name'] ?? 'No name set'}\n'
              'Birth data: ${hasBirthData ? 'Saved' : 'Not saved'}\n'
              'Questions asked: $questions\n'
              'Appointment requests: $appointments',
              style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
              Navigator.of(dialogContext).pop();
              toast(context, 'Full data copied to clipboard as JSON');
            },
            child: Text('COPY AS JSON',
                style: AppText.sans(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('CLOSE', style: AppText.sans(size: 13, color: AppColors.textTan)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    try {
      await UserApi.deleteAccount();
      if (!mounted) return;
      goToLogin(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't reach the server — check your connection.");
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Privacy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Your data, your control', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Export everything we hold on you, or permanently delete your account.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),

          const SectionLabel('YOUR DATA'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconChip(
                        child: const Icon(Icons.download_outlined,
                            size: 18, color: AppColors.gold)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Export my data', style: AppText.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            'A copy of your profile, birth data, questions and '
                            'appointment history.',
                            style: AppText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                GoldButton(
                  label: _exporting ? 'EXPORTING…' : 'EXPORT MY DATA',
                  outlined: true,
                  onPressed: _exporting ? null : _exportData,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionLabel('DANGER ZONE'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            borderColor: AppColors.criticalText.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delete account', style: AppText.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Permanently deletes your profile, birth data, charts and '
                  'consultation history. This cannot be undone.',
                  style: AppText.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.criticalText.withValues(alpha: 0.5)),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: _deleting ? null : () => _confirmDelete(context),
                    child: Text(_deleting ? 'DELETING…' : 'DELETE MY ACCOUNT',
                        style: AppText.sans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: AppColors.criticalText,
                            letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navBarBase,
        title: Text('Delete your account?',
            style: AppText.serif(size: 18, color: AppColors.textPrimary)),
        content: Text(
          'This permanently removes your profile, birth data, saved charts '
          'and consultation history. This cannot be undone.',
          style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('CANCEL', style: AppText.sans(size: 13, color: AppColors.textTan)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteAccount();
            },
            child: Text('DELETE',
                style: AppText.sans(
                    size: 13, weight: FontWeight.w700, color: AppColors.criticalText)),
          ),
        ],
      ),
    );
  }
}

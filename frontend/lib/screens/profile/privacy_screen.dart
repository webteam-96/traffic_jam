import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// Privacy — Business Flow §12 step 7: export all data, delete account, and
/// view the record of consents given. No backend exists yet, so export and
/// delete are mocked confirmations rather than real destructive actions.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _consents = <_Consent>[
    _Consent('Birth data usage', 'Accepted', '24 Oct 2024'),
    _Consent('Marketing communications', 'Declined', '24 Oct 2024'),
    _Consent('Consultation chart sharing', 'Accepted', '02 Mar 2025'),
  ];

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
            'Export everything we hold on you, review your consent history, '
            'or permanently delete your account.',
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
                            'A copy of your profile, birth data and chart '
                            'history as a downloadable file.',
                            style: AppText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                GoldButton(
                  label: 'REQUEST EXPORT',
                  outlined: true,
                  onPressed: () => toast(
                      context, "Export requested — we'll email it within 48 hours"),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionLabel('CONSENT HISTORY'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < _consents.length; i++)
                  _ConsentRow(consent: _consents[i], last: i == _consents.length - 1),
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
                    onPressed: () => _confirmDelete(context),
                    child: Text('DELETE MY ACCOUNT',
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
              goToLogin(context);
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

class _Consent {
  const _Consent(this.title, this.status, this.date);
  final String title;
  final String status;
  final String date;
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.consent, required this.last});
  final _Consent consent;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final accepted = consent.status == 'Accepted';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderFaint)),
      ),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 16,
            color: accepted ? AppColors.gold : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(consent.title, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text('${consent.status} · ${consent.date}', style: AppText.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

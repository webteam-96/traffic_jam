import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/user_api.dart';
import 'package:traffic_jam/services/consult_api.dart';
import 'package:traffic_jam/services/api_client.dart';
import 'package:traffic_jam/nav.dart';

/// Book an Appointment — §9 of Business Flow.
/// Lead-capture form prefilled with the signed-in user's real birth data,
/// submitted to POST /consult/appointments. No scheduling/admin panel
/// exists yet (Phase 2), so it lands as a Pending request the team follows
/// up on using the reference number this screen shows back.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  static const _areas = [
    'Career',
    'Relationship',
    'Profession & Business',
    'General Guidance',
    'Other',
  ];

  int _areaIndex = 0;
  final _email = TextEditingController();
  final _message = TextEditingController();
  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;
  bool _consent = false;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  String? _name;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    UserApi.getBirthData().then((data) {
      if (!mounted) return;
      setState(() {
        _name = data?['name'] as String?;
        _loadingProfile = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loadingProfile = false);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Book Appointment',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('CONSULTATION REQUEST'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Fill in your details and preferred time. Our team will reach out '
              'to confirm the appointment.',
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Prefilled identity ───────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('YOUR DETAILS'),
                  const SizedBox(height: AppSpacing.md),
                  _readonlyField(
                    'Full Name',
                    _loadingProfile ? 'Loading…' : (_name ?? 'Not set — add it in your profile'),
                    Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: AppText.sans(size: 16, color: AppColors.textPrimary),
                    decoration: _inputDecoration('Email Address', Icons.email_outlined),
                    validator: (v) =>
                        v != null && v.contains('@') ? null : 'Enter a valid email',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Consultation Area ────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('CONSULTATION AREA'),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    initialValue: _areaIndex,
                    decoration: _inputDecoration('Select Area', Icons.category_outlined),
                    dropdownColor: AppColors.surfaceRaised,
                    style: AppText.sans(size: 16, color: AppColors.textPrimary),
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
                    items: [
                      for (int i = 0; i < _areas.length; i++)
                        DropdownMenuItem(value: i, child: Text(_areas[i])),
                    ],
                    onChanged: (v) => setState(() => _areaIndex = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Preferred Date & Time ────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('PREFERRED DATE & TIME'),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Date',
                          value: _preferredDate != null
                              ? '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}'
                              : 'Select date',
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _DatePickerField(
                          label: 'Time',
                          value: _preferredTime != null
                              ? _preferredTime!.format(context)
                              : 'Select time',
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Message ──────────────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('YOUR MESSAGE (OPTIONAL)'),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _message,
                    maxLines: 4,
                    maxLength: 500,
                    style: AppText.sans(size: 16, color: AppColors.textPrimary),
                    decoration: _inputDecoration(
                      'Describe what you\'d like guidance on...',
                      Icons.message_outlined,
                    ).copyWith(
                      counterText: '',
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Consent ──────────────────────────────────────────────────
            GlassCard(
              fill: AppColors.surfaceRaised,
              fillOpacity: 0.6,
              borderColor: AppColors.goldBorderSoft,
              goldTopBorder: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    activeColor: AppColors.gold,
                    checkColor: AppColors.textOnGold,
                    side: const BorderSide(color: AppColors.gold, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'I authorize the Traffic Jam team to use my birth details and '
                        'chart context during the consultation for an accurate reading.',
                        style: AppText.sans(
                            size: 13, color: AppColors.textTan, height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Submit ───────────────────────────────────────────────────
            GoldButton(
              label: _submitting ? 'SUBMITTING…' : 'SUBMIT REQUEST',
              icon: Icons.send,
              onPressed: _consent && !_submitting ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.section),

            // ── What happens next ────────────────────────────────────────
            GlassCard(
              fill: AppColors.surfaceRaised,
              fillOpacity: 0.4,
              borderColor: AppColors.borderSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('WHAT HAPPENS NEXT'),
                  const SizedBox(height: AppSpacing.md),
                  _StepRow(
                    '1',
                    'Request received',
                    'You\'ll get a confirmation with a reference number.',
                  ),
                  _StepRow(
                    '2',
                    'Team reviews',
                    'Astrologer Jay or a panel astrologer reviews your chart context.',
                  ),
                  _StepRow(
                    '3',
                    'Scheduling',
                    'We\'ll contact you to confirm the exact date, time, and mode.',
                  ),
                  _StepRow(
                    '4',
                    'Consultation',
                    'Session happens via phone/video. Recording provided afterward.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.sans(size: 16, color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      filled: true,
      fillColor: AppColors.bgDeep,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.goldBorderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.critical, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.critical, width: 1.5),
      ),
    );
  }

  Widget _readonlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.microLabel),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textMuted, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text(value,
                  style: AppText.sans(
                      size: 16, weight: FontWeight.w500, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _preferredTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preferredDate == null || _preferredTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a date and time',
            style: AppText.sans(size: 14, color: AppColors.textPrimary)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised2,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ConsultApi.bookAppointment(
        area: _areas[_areaIndex],
        email: _email.text.trim(),
        message: _message.text.trim().isEmpty ? null : _message.text.trim(),
        preferredDate: _preferredDate!,
        preferredHour24: _preferredTime!.hour,
        preferredMinute: _preferredTime!.minute,
      );
      if (!mounted) return;
      _showConfirmation(result['reference'] as String);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't reach the server — check your connection.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showConfirmation(String reference) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Request Submitted', style: AppText.serif(size: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your consultation request has been received.',
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reference: $reference',
              style: AppText.sans(size: 14, color: AppColors.amber),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Our team will contact you to schedule your session.',
              style: AppText.bodySmall,
            ),
          ],
        ),
        actions: [
          GoldButton(
            label: 'DONE',
            expand: false,
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to previous screen
            },
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.microLabel),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgDeep,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.goldBorderSoft),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value,
                    style: AppText.sans(
                        size: 16,
                        weight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.number, this.title, this.desc);
  final String number;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.goldBorderSoft),
            ),
            child: Text(number,
                style: AppText.sans(
                    size: 12, weight: FontWeight.w700, color: AppColors.gold)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.sans(
                        size: 14, weight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(desc, style: AppText.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
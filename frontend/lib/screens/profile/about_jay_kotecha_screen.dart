import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/theme/app_assets.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/services/api_client.dart';
import 'package:traffic_jam/services/astrologer_api.dart';

/// About Astrologer Jay Kotecha — §13 of Business Flow.
/// Dedicated trust-building screen with bio, expertise, philosophy, insights,
/// testimonials, and CTAs.
///
/// Every word and the portrait come from GET /astrologer, which the team edits
/// in the admin panel. This was hardcoded until then, so correcting a line of
/// Jay's biography meant shipping a new build.
class AboutJayKotechaScreen extends StatefulWidget {
  const AboutJayKotechaScreen({super.key});

  @override
  State<AboutJayKotechaScreen> createState() => _AboutJayKotechaScreenState();
}

class _AboutJayKotechaScreenState extends State<AboutJayKotechaScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _myReview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await AstrologerApi.getProfile();
      // Fetched separately and tolerantly: a failure here should cost the
      // reader the review form, not the whole About page.
      Map<String, dynamic>? mine;
      try {
        mine = await AstrologerApi.getMyReview();
      } catch (_) {
        mine = null;
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _myReview = mine;
        _loading = false;
      });
    } catch (_) {
      // Falls through to the seeded defaults below rather than showing an
      // error page — an About screen with slightly stale copy is far better
      // than no About screen.
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _lines(String key, List<String> fallback) {
    final value = _profile?[key];
    if (value is! List || value.isEmpty) return fallback;
    return value.cast<String>();
  }

  String _text(String key, String fallback) {
    final value = _profile?[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  /// The app's portrait size. The admin panel crops to a square at 4x this
  /// (ImageCropper.tsx's EXPORT_PX), so the two must stay in step — change one
  /// and the other should follow.
  static const double _portraitSize = 100;

  /// The admin-uploaded photo, already cropped square and resized to 400x400
  /// by the admin panel, so nothing needs rescaling here beyond fitting it to
  /// the circle. The bundled asset stands in when none has been set, so the
  /// screen is never portrait-less.
  Widget _portrait() {
    final uri = _profile?['imageDataUri'];
    if (uri is String && uri.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(uri.substring(uri.indexOf(',') + 1)),
          width: _portraitSize,
          height: _portraitSize,
          fit: BoxFit.cover,
          // The source is already square at 4x, so let Flutter downscale it
          // with that in mind rather than decoding a 400px bitmap for a 100px
          // slot on every build.
          cacheWidth: (_portraitSize * MediaQuery.devicePixelRatioOf(context)).round(),
          // A corrupt upload shouldn't leave a broken box on the screen.
          errorBuilder: (_, _, _) => _bundledPortrait(),
        );
      } catch (_) {
        return _bundledPortrait();
      }
    }

    return _bundledPortrait();
  }

  /// Reviews as stored, in the admin's chosen order. Empty simply renders no
  /// testimonials rather than placeholder ones — a fresh install with none
  /// added should show none.
  List<Map<String, dynamic>> get _reviews {
    final value = _profile?['reviews'];
    if (value is! List) return const [];
    return value.cast<Map<String, dynamic>>();
  }

  /// The reader's own review: the form, or where their submission stands.
  /// A pending review is shown back to them because it is invisible to
  /// everyone else — without this it would look like nothing was submitted.
  Widget _reviewCard() {
    final status = _myReview?['status'] as String?;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('YOUR REVIEW'),
          const SizedBox(height: AppSpacing.md),
          if (status == 'Approved') ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Published — thank you.',
                      style: AppText.body.copyWith(color: AppColors.textCream)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('"${_myReview!['quote']}"', style: AppText.bodySmall),
          ] else if (status == 'Pending') ...[
            Row(
              children: [
                const Icon(Icons.hourglass_empty,
                    size: 18, color: AppColors.amber),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Submitted — waiting for the team to review it.',
                      style: AppText.body.copyWith(color: AppColors.textCream)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('"${_myReview!['quote']}"', style: AppText.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            GoldButton(
              label: 'EDIT MY REVIEW',
              outlined: true,
              onPressed: _openReviewSheet,
            ),
          ] else ...[
            Text(
              status == 'Rejected'
                  // Said plainly rather than left ambiguous — the alternative
                  // is a review that silently never appears.
                  ? "Your last review wasn't published. You're welcome to write another."
                  : 'Been read by Jay? Tell others how it went.',
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            GoldButton(
              label: status == 'Rejected' ? 'WRITE ANOTHER' : 'WRITE A REVIEW',
              icon: Icons.rate_review_outlined,
              onPressed: _openReviewSheet,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openReviewSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(existing: _myReview),
    );

    if (submitted == true) {
      if (!mounted) return;
      toast(context, 'Thanks — your review is with the team.');
      await _load();
    }
  }

  Widget _bundledPortrait() => Image.asset(
        figmaAsset(Assets.avatar),
        width: _portraitSize,
        height: _portraitSize,
        fit: BoxFit.cover,
      );

  // Shown only if the fetch fails — the server seeds these same words, so in
  // practice this is a stale-copy fallback rather than different content.
  static const _fallbackBio = [
    'Jay Kotecha is a practicing Vedic astrologer with over 18 years of experience '
        'guiding individuals and businesses through life\'s critical intersections.',
    'Jay founded TrafficJam.Life to democratize access to authentic, '
        'birth-chart-level guidance.',
  ];

  static const _fallbackExpertise = [
    'Vedic Astrology (Parashara)',
    'KP System (Krishnamurti Paddhati)',
    'Prashna / Horary Astrology',
    'Remedial Astrology (Mantra, Yantra, Dana)',
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailScaffold(
          title: 'About Jay Kotecha', child: LoadingView());
    }

    return DetailScaffold(
      title: 'About Jay Kotecha',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Portrait & name ────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: _portraitSize,
                  height: _portraitSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(color: AppColors.goldBorderSoft),
                  ),
                  child: ClipOval(child: _portrait()),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(_text('name', 'Jay Kotecha'),
                    style: AppText.serif(size: 28, weight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text(_text('title', 'Founder & Chief Astrologer'),
                    style: AppText.sans(
                        size: 14, color: AppColors.textTan, letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Biography ──────────────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('BIOGRAPHY'),
                const SizedBox(height: AppSpacing.md),
                for (final (i, paragraph) in _lines('bio', _fallbackBio).indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  Text(
                    paragraph,
                    // The closing paragraph is the mission statement, picked
                    // out in amber the way the original layout did.
                    style: i == _lines('bio', _fallbackBio).length - 1
                        ? AppText.body.copyWith(color: AppColors.amber)
                        : AppText.body,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Areas of Expertise ─────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('AREAS OF EXPERTISE'),
                const SizedBox(height: AppSpacing.lg),
                for (final area in _lines('expertise', _fallbackExpertise))
                  _ExpertiseChip(area),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Philosophy ─────────────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('PHILOSOPHY & APPROACH'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '"${_text('philosophy', 'Astrology is a compass, not a verdict.')}"',
                  style: AppText.serif(size: 18, height: 1.5, color: AppColors.textCream),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: AppColors.gold, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Play Philosophy Statement',
                              style: AppText.sans(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: AppColors.gold)),
                          Text('2:14 min • Audio narration by Jay',
                              style: AppText.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Featured Insights ──────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('FEATURED INSIGHTS'),
                const SizedBox(height: AppSpacing.md),
                _InsightItem(
                  date: 'August 2026',
                  title: 'Saturn Retrograde in Pisces: The Karmic Review',
                  excerpt:
                      'Saturn\'s retrograde through Pisces until November invites a collective '
                      'reckoning with spiritual debts and unconscious patterns...',
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.borderFaint, height: 1),
                const SizedBox(height: AppSpacing.md),
                _InsightItem(
                  date: 'July 2026',
                  title: 'Jupiter in Gemini: The Curious Expansion',
                  excerpt:
                      'Jupiter\'s transit through Gemini amplifies communication, learning, '
                      'and short-distance travel. For mutable ascendants...',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Testimonials ───────────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('CLIENT TESTIMONIALS'),
                const SizedBox(height: AppSpacing.md),
                if (_reviews.isEmpty)
                  Text('No reviews yet — yours could be the first.',
                      style: AppText.bodySmall),
                for (final (i, review) in _reviews.indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  _Testimonial(
                    // _Testimonial adds the quotation marks itself.
                    quote: review['quote'] as String,
                    author: '— ${review['author']}',
                    rating: review['rating'] as int?,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _reviewCard(),
          const SizedBox(height: AppSpacing.xxl),

          // ── CTA Buttons ────────────────────────────────────────────────
          GoldButton(
            label: 'ASK JAY A QUESTION',
            icon: Icons.chat_bubble_outline,
            onPressed: () => goToAskJayTab(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          GoldButton(
            label: 'BOOK AN APPOINTMENT',
            icon: Icons.calendar_month,
            outlined: true,
            onPressed: () => goToBookAppointment(context),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ExpertiseChip extends StatelessWidget {
  const _ExpertiseChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.navBarBase.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.goldBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 14, color: AppColors.amber),
            const SizedBox(width: AppSpacing.sm),
            Text(label,
                style: AppText.sans(
                    size: 13, weight: FontWeight.w500, color: AppColors.textCream)),
          ],
        ),
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  const _InsightItem({
    required this.date,
    required this.title,
    required this.excerpt,
  });
  final String date;
  final String title;
  final String excerpt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date,
            style: AppText.sans(
                size: 11, weight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        Text(title,
            style: AppText.sans(
                size: 16, weight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(excerpt, style: AppText.bodySmall),
      ],
    );
  }
}

class _Testimonial extends StatelessWidget {
  const _Testimonial({required this.quote, required this.author, this.rating});
  final String quote;
  final String author;

  /// Null for the team's own curated testimonials, which carry no rating.
  final int? rating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rating != null) ...[
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(i <= rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 15, color: AppColors.gold),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text('"$quote"',
            style: AppText.sans(
                size: 14, color: AppColors.textTan, height: 20 / 14)),
        const SizedBox(height: AppSpacing.sm),
        Text(author,
            style: AppText.sans(
                size: 12, weight: FontWeight.w700, color: AppColors.textCream)),
      ],
    );
  }
}

/// Write-a-review sheet. Kept as a bottom sheet rather than a pushed screen so
/// the reader doesn't lose their place on a long About page.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _quote =
      TextEditingController(text: widget.existing?['quote'] as String? ?? '');
  late int _rating = widget.existing?['rating'] as int? ?? 5;
  bool _sending = false;

  static const _minLength = 10;

  @override
  void dispose() {
    _quote.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await AstrologerApi.submitReview(quote: _quote.text.trim(), rating: _rating);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      toast(context, "Couldn't send your review — check your connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooShort = _quote.text.trim().length < _minLength;

    return Padding(
      // Lifts the sheet clear of the keyboard, which otherwise covers the
      // send button on a short screen.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Write a review',
                style: AppText.serif(size: 22, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Shared publicly on this page under your name, once the team has '
              'read it.',
              style: AppText.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => setState(() => _rating = i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(
                        i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 32,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _quote,
              maxLines: 5,
              maxLength: 600,
              onChanged: (_) => setState(() {}),
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'What was your reading like?',
                hintStyle: AppText.bodySmall,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderSoft),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderSoft),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GoldButton(
              label: _sending ? 'SENDING…' : 'SUBMIT REVIEW',
              onPressed: _sending || tooShort ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                tooShort
                    ? 'A few more words, please.'
                    : "It'll appear here once approved.",
                style: AppText.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

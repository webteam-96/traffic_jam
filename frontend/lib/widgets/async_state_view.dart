import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/app_widgets.dart';

/// The gold spinner, in one place.
///
/// Every data screen used to inline its own `CircularProgressIndicator` with
/// the same stroke width and colour, so a change to how loading looks meant
/// finding all twenty of them.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.height = 400, this.message});

  /// Height of the space the spinner centres itself in. Null sizes to the
  /// spinner itself, for use inline inside an already-laid-out column.
  final double? height;

  /// Optional line under the spinner, for waits long enough that a bare
  /// spinner reads as a hang.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(message!, textAlign: TextAlign.center, style: AppText.body),
        ],
      ],
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(child: content),
    );
  }
}

/// A failed load, with a way out of it.
///
/// The app previously ended a failed request at a dead sentence — "Couldn't
/// load … check your connection" — and nothing else. Since every screen loads
/// once in `initState`, that state was permanent: a dropped connection, a
/// backend restart, or a phone that woke on a different network left the
/// screen wrong until the whole app was force-quit and reopened. Restarting
/// an app to re-issue a GET is not something a user should ever have to work
/// out for themselves.
///
/// So a failure always offers the retry, and [onRetry] re-runs the same load
/// the screen ran at startup.
class RetryView extends StatefulWidget {
  const RetryView({
    super.key,
    required this.onRetry,
    this.message,
    this.height = 400,
  });

  /// Re-runs the screen's load. Awaited, so the button can show progress and
  /// can't be fired twice in parallel by an impatient double tap.
  final Future<void> Function() onRetry;

  /// What failed, in the screen's own words ("Couldn't load today's
  /// Panchang"). The connection hint is appended here, so callers don't each
  /// rephrase it.
  final String? message;

  final double? height;

  @override
  State<RetryView> createState() => _RetryViewState();
}

class _RetryViewState extends State<RetryView> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      // The retry usually rebuilds this widget out of existence — guard so
      // the successful case doesn't setState on a dead State.
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message ?? "Couldn't load this";

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: AppColors.textMuted, size: 36),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '$message — check your connection.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_retrying)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(AppColors.gold),
                  ),
                )
              else
                GoldButton(
                  label: 'TRY AGAIN',
                  icon: Icons.refresh,
                  expand: false,
                  height: 48,
                  onPressed: _retry,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

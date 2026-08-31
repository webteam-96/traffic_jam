import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Path helper for downloaded Figma SVG/PNG assets (named by their hash).
String figmaAsset(String hashWithExt) => 'assets/figma/$hashWithExt';

/// Renders a Figma-exported SVG. These use `var(--fill,..)` which flutter_svg
/// can't resolve, so we tint the whole glyph with a ColorFilter (srcIn).
/// Pass [color] = null to keep the SVG's own (fallback) colors.
class SvgIcon extends StatelessWidget {
  const SvgIcon(
    this.assetHash, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.color = AppColors.gold,
    this.fit = BoxFit.contain,
  });

  final String assetHash; // e.g. "abc123.svg"
  final double? size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      figmaAsset(assetHash),
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

/// Small uppercase amber section label — "TODAY'S PANCHANG", "ACTIVE PLAN".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = AppColors.amber});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppText.sectionLabel.copyWith(color: color));
}

/// Round-square icon chip with translucent gold background (action hub,
/// educational cards). [circular] makes it a full circle (educational grid).
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.child,
    this.size = 40,
    this.circular = false,
    this.glow = false,
  });

  final Widget child;
  final double size;
  final bool circular;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.amber.withValues(alpha: 0.16),
            AppColors.amber.withValues(alpha: 0.06),
          ],
        ),
        borderRadius:
            BorderRadius.circular(circular ? size : AppRadius.sm),
        border: Border.all(color: AppColors.goldBorderSoft),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.2),
                  blurRadius: 15,
                )
              ]
            : null,
      ),
      child: Center(child: child),
    );
  }
}

/// Primary gold button (filled) or outlined variant. Dark-brown label, glow.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.outlined = false,
    this.expand = true,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon,
              size: 18,
              color: outlined ? AppColors.gold : AppColors.textOnGold),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: AppText.button.copyWith(
            color: outlined ? AppColors.gold : AppColors.textOnGold,
          ),
        ),
      ],
    );

    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Material(
        color: outlined ? Colors.transparent : AppColors.goldButton,
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: outlined ? 0 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: expand ? 0 : 28),
            decoration: BoxDecoration(
              gradient: outlined ? null : AppColors.goldButtonGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: outlined
                  ? Border.all(color: AppColors.gold, width: 1.4)
                  : null,
              boxShadow: outlined
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.goldButton.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ],
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// Label + percentage + gold gradient progress bar (Celestial Vibe Meter).
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.label,
    required this.value, // 0..1
    this.glow = true,
  });

  final String label;
  final double value;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.96)),
            Text('${(value * 100).round()}%',
                style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w500,
                    color: AppColors.amber,
                    letterSpacing: 0.96)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            height: 4,
            color: AppColors.bgDeep,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldMeter,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: glow
                      ? [
                          BoxShadow(
                            color: AppColors.amber.withValues(alpha: 0.5),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal segmented pill selector (Ask Jay domains, chart toggles).
class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (int i = 0; i < options.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: i == selectedIndex
                    ? AppColors.amber.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: i == selectedIndex
                      ? AppColors.gold
                      : AppColors.borderSoft,
                ),
              ),
              child: Text(
                options[i],
                style: AppText.sans(
                  size: 14,
                  weight: FontWeight.w500,
                  color: i == selectedIndex
                      ? AppColors.gold
                      : AppColors.textTan,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

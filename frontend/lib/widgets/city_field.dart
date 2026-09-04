import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/glass_card.dart';
import 'package:traffic_jam/data/world_cities.dart';

/// Search-and-pick a city, used everywhere a birth place is chosen so the
/// interaction is identical on every screen.
///
/// The list collapses the moment a city is picked, leaving just the chosen
/// one on screen. That matters because the dataset returns hundreds of
/// matches: with the list left open, whatever button follows this field
/// (Continue, Generate, Save) is pushed hundreds of rows down the page and
/// is effectively unreachable — you appear to have finished, but the next
/// step is nowhere in sight.
///
/// Typing again reopens the list; picking closes it again. The selected card
/// is also tappable, so a place can be changed without knowing to type first.
class CityField extends StatefulWidget {
  const CityField({
    super.key,
    required this.cities,
    required this.popular,
    required this.selected,
    required this.onSelected,
    this.loading = false,
    this.hintText = 'Search your city',
  });

  /// The full dataset to search.
  final List<CityEntry> cities;

  /// Shown before anything is typed — a short starter list, not search results.
  final List<CityEntry> popular;

  final CityEntry? selected;
  final ValueChanged<CityEntry> onSelected;

  /// Dataset still loading; shows a spinner in place of the list.
  final bool loading;

  final String hintText;

  @override
  State<CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<CityField> {
  final _search = TextEditingController();

  /// Whether the list is open. Starts open only when there's nothing chosen
  /// yet — arriving with a place already saved (editing birth data, coming
  /// back to a step) should show that place, not a wall of suggestions.
  late bool _browsing = widget.selected == null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CityEntry> get _results {
    final q = _search.text.trim();
    if (q.isEmpty) return widget.popular;
    return WorldCities.search(widget.cities, q);
  }

  void _select(CityEntry city) {
    // Clear the query too: the next search starts fresh rather than making
    // someone delete the old city's name first.
    _search.clear();
    FocusScope.of(context).unfocus();
    setState(() => _browsing = false);
    widget.onSelected(city);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          textCapitalization: TextCapitalization.words,
          cursorColor: AppColors.gold,
          style: AppText.sans(
              size: 16, weight: FontWeight.w500, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppText.sans(size: 16, color: AppColors.textMuted),
            prefixIcon:
                const Icon(Icons.location_on_outlined, color: AppColors.gold),
            filled: true,
            fillColor: AppColors.bgDeep,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.goldBorderSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
          // Any typing reopens the list; clearing the box back to empty with a
          // city already chosen collapses it again rather than dumping the
          // suggestions back on top of the button.
          onChanged: (value) => setState(
              () => _browsing = value.trim().isNotEmpty || selected == null),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_browsing && selected != null)
          _CityCard(
            city: selected,
            selected: true,
            onTap: () => setState(() => _browsing = true),
            trailingHint: 'Change',
          )
        else if (widget.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.gold)),
            ),
          )
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('No cities match your search.', style: AppText.body),
          )
        else
          for (final city in _results) ...[
            _CityCard(
              city: city,
              selected: city.displayName == selected?.displayName,
              onTap: () => _select(city),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.city,
    required this.selected,
    required this.onTap,
    this.trailingHint,
  });

  final CityEntry city;
  final bool selected;
  final VoidCallback onTap;
  final String? trailingHint;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      borderColor: selected ? AppColors.gold : AppColors.borderFaint,
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.location_on,
              color: selected ? AppColors.gold : AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              city.displayName,
              style: AppText.sans(
                  size: 15,
                  weight: FontWeight.w500,
                  color: AppColors.textPrimary),
            ),
          ),
          if (trailingHint != null)
            Text(trailingHint!,
                style: AppText.sans(size: 13, color: AppColors.gold))
          else if (selected)
            const Icon(Icons.check_circle, color: AppColors.gold, size: 20),
        ],
      ),
    );
  }
}

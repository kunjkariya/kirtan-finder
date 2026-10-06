import 'package:flutter/material.dart';
import '../../../core/models/part.dart';

/// Minimal monochrome filter bar for toggling between All Parts and Parts 1–4.
class PartFilterBar extends StatelessWidget {
  final PartFilter selectedFilter;
  final ValueChanged<PartFilter> onFilterChanged;

  const PartFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: PartFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = PartFilter.values[index];
          final isSelected = filter == selectedFilter;

          final bg = isSelected
              ? (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111))
              : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7));

          final fg = isSelected
              ? (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
              : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73));

          final border = isSelected
              ? (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111))
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA));

          return Semantics(
            label: '${filter.labelEn} filter',
            selected: isSelected,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onFilterChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  filter.labelEn,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

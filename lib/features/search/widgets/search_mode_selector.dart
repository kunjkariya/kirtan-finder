import 'package:flutter/material.dart';
import '../search_state.dart';

/// Minimal monochrome segmented control for switching between Search 1 (Title / ID)
/// and Search 2 (Kirtan Lines).
class SearchModeSelector extends StatelessWidget {
  final SearchMode selectedMode;
  final ValueChanged<SearchMode> onModeChanged;

  const SearchModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Semantics(
        label: 'Select search mode',
        child: SegmentedButton<SearchMode>(
          segments: const [
            ButtonSegment<SearchMode>(
              value: SearchMode.titleNumber,
              icon: Icon(Icons.title, size: 16),
              label: Text(
                'Title / ID',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            ButtonSegment<SearchMode>(
              value: SearchMode.lyrics,
              icon: Icon(Icons.format_quote_rounded, size: 16),
              label: Text(
                'Kirtan Lines',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
          selected: {selectedMode},
          onSelectionChanged: (newSelection) {
            if (newSelection.isNotEmpty) {
              onModeChanged(newSelection.first);
            }
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
              }
              return isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
              }
              return isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73);
            }),
            side: WidgetStateProperty.all(
              BorderSide(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                width: 1,
              ),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    );
  }
}

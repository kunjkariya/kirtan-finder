import 'package:flutter/material.dart';
import '../../../core/models/search_result.dart';

/// Clean, classic monochrome search result card displaying:
/// - n#### ID (subtle, understated)
/// - Canonical Hindi title (dominant, clear typography)
/// - English transliteration (secondary)
/// - Part · Chapter · Page · Raag (metadata row)
/// - Matching lyric snippet for Search 2 (with bold highlight)
class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final Widget? trailing;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final chapterDisplay = (result.chapterTitle != null && result.chapterTitle!.trim().isNotEmpty)
        ? result.chapterTitle!
        : 'Ch ${result.chapterNumber}';

    // Metadata items: Part · Chapter · Page · Raag
    final metaItems = <String>[
      'Part ${result.partNumber}',
      chapterDisplay,
      'Page ${result.oldPage}',
      if (result.raagNormalized.isNotEmpty) result.raagNormalized,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Subtle Public ID + Trailing action (if any)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.uniqueKirtanId,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF3A3A3C),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 6),

              // Canonical Hindi Title (Main content, high contrast)
              Text(
                result.titleHi,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                ),
              ),

              // English Transliteration
              if (result.titleEn.isNotEmpty && result.titleEn != result.titleHi) ...[
                const SizedBox(height: 3),
                Text(
                  result.titleEn,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Metadata Row: Part · Chapter · Page · Raag
              Text(
                metaItems.join('  ·  '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                  letterSpacing: -0.1,
                ),
              ),

              // Search 2 Matching Lyric Snippet
              if (result.matchingSnippet != null && result.matchingSnippet!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : const Color(0xFFF6F6F8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      width: 0.8,
                    ),
                  ),
                  child: _HighlightedSnippet(
                    snippetText: result.matchingSnippet!,
                    isDark: isDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedSnippet extends StatelessWidget {
  final String snippetText;
  final bool isDark;

  const _HighlightedSnippet({
    required this.snippetText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final markRegex = RegExp(r'<mark>(.*?)</mark>');
    int lastEnd = 0;

    for (final match in markRegex.allMatches(snippetText)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: snippetText.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
            height: 1.45,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          backgroundColor: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
          color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          height: 1.45,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < snippetText.length) {
      spans.add(TextSpan(
        text: snippetText.substring(lastEnd),
        style: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
          height: 1.45,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

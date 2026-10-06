import 'package:flutter/material.dart';
import '../../../core/models/kirtan.dart';

/// Header widget displaying kirtan metadata in strict hierarchy:
/// 1. Public Kirtan ID (e.g. n1541)
/// 2. Canonical Hindi Title (large, visually dominant)
/// 3. English Transliteration Title (secondary, smaller)
/// 4. Compact Metadata (Part, Chapter, Page, Raag)
class KirtanHeader extends StatelessWidget {
  final Kirtan kirtan;

  const KirtanHeader({super.key, required this.kirtan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Public Kirtan ID (e.g. n1541)
          if (kirtan.uniqueKirtanId.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                kirtan.uniqueKirtanId,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF3A3A3C),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 2. Canonical Hindi Title (Visually dominant)
          SelectableText(
            kirtan.titleHi,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
            ),
          ),

          // 3. English Transliteration Title (Secondary)
          if (kirtan.titleEn.isNotEmpty && kirtan.titleEn != kirtan.titleHi) ...[
            const SizedBox(height: 6),
            SelectableText(
              kirtan.titleEn,
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.3,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 4. Compact Metadata Badges (English labels, monochrome styling)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(
                label: 'Part ${kirtan.partNumber}',
                isDark: isDark,
              ),
              if (kirtan.chapterTitle != null && kirtan.chapterTitle!.trim().isNotEmpty) ...[
                _Tag(
                  label: kirtan.chapterTitle!,
                  isDark: isDark,
                ),
                _Tag(
                  label: 'Kirtan ${kirtan.kirtanNumber}',
                  isDark: isDark,
                ),
              ] else ...[
                _Tag(
                  label: 'Ch ${kirtan.chapterNumber} • Kirtan ${kirtan.kirtanNumber}',
                  isDark: isDark,
                ),
              ],
              _Tag(
                label: 'Page ${kirtan.oldPage}',
                isDark: isDark,
              ),
              if (kirtan.raagNormalized.isNotEmpty)
                _Tag(
                  label: 'Raag: ${kirtan.raagNormalized}',
                  isDark: isDark,
                ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool isDark;

  const _Tag({
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

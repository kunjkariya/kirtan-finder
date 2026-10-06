import 'package:flutter/material.dart';
import '../../../core/models/kirtan_line.dart';

/// Renders authentic, structured devotional lyrics from the `kirtan_lines` table.
///
/// Features:
/// - Preserves authentic line breaks, stanza groupings, and verse markers (॥१॥, ॥२॥)
/// - Devanagari-optimized typography with adjustable [fontSize] and generous line-height
/// - Search 2 matched-line highlighting and smooth auto-scroll to the first match
/// - Clean, uncluttered reading design without heavy cards or unnecessary borders
class KirtanLyrics extends StatefulWidget {
  final List<KirtanLine> lines;
  final double fontSize;
  final String? highlightQuery;

  const KirtanLyrics({
    super.key,
    required this.lines,
    this.fontSize = 20.0,
    this.highlightQuery,
  });

  @override
  State<KirtanLyrics> createState() => _KirtanLyricsState();
}

class _KirtanLyricsState extends State<KirtanLyrics> {
  final GlobalKey _firstMatchKey = GlobalKey();
  bool _hasScrolledToMatch = false;
  int _firstMatchLineIndex = -1;
  List<String> _queryTokens = [];

  @override
  void initState() {
    super.initState();
    _initHighlighting();
  }

  @override
  void didUpdateWidget(KirtanLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightQuery != widget.highlightQuery || oldWidget.lines != widget.lines) {
      _hasScrolledToMatch = false;
      _initHighlighting();
    }
  }

  void _initHighlighting() {
    final query = widget.highlightQuery?.trim();
    if (query == null || query.isEmpty) {
      _queryTokens = [];
      _firstMatchLineIndex = -1;
      return;
    }

    if (query.startsWith('"') && query.endsWith('"') && query.length > 2) {
      _queryTokens = [query.substring(1, query.length - 1).trim()];
    } else {
      _queryTokens = query
          .replaceAll(RegExp(r'["\x27\*\(\)\{\}\[\]\^\~]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
    }

    _firstMatchLineIndex = -1;
    if (_queryTokens.isNotEmpty) {
      for (int i = 0; i < widget.lines.length; i++) {
        final lineText = widget.lines[i].lineText;
        if (_lineMatches(lineText)) {
          _firstMatchLineIndex = i;
          break;
        }
      }
    }

    if (_firstMatchLineIndex >= 0 && !_hasScrolledToMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _firstMatchKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.15,
          );
          _hasScrolledToMatch = true;
        }
      });
    }
  }

  bool _lineMatches(String text) {
    for (final token in _queryTokens) {
      if (text.contains(token)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'No lyric lines available',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(widget.lines.length, (index) {
          final line = widget.lines[index];
          final isFirstMatch = index == _firstMatchLineIndex;

          return Container(
            key: isFirstMatch ? _firstMatchKey : null,
            child: _buildLineItem(context, line, index),
          );
        }),
      ),
    );
  }

  Widget _buildLineItem(BuildContext context, KirtanLine line, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasMarker = line.verseMarker != null && line.verseMarker!.isNotEmpty;
    final isStanzaEnd = line.isVerseEnd;

    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: 1.8,
      fontWeight: line.isTitleLine ? FontWeight.w700 : FontWeight.w500,
      color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
      letterSpacing: 0.2,
    );

    final lineSpans = _buildTextSpans(line.lineText, baseStyle, isDark);

    return Padding(
      padding: EdgeInsets.only(
        top: 4.0,
        bottom: isStanzaEnd ? 22.0 : 4.0,
      ),
      child: SelectableText.rich(
        TextSpan(
          children: [
            ...lineSpans,
            if (hasMarker) ...[
              const TextSpan(text: '  '),
              TextSpan(
                text: line.verseMarker,
                style: TextStyle(
                  fontSize: widget.fontSize * 0.88,
                  fontWeight: FontWeight.w700,
                  color: baseStyle.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text, TextStyle baseStyle, bool isDark) {
    if (_queryTokens.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    final markBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6);
    final markFg = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

    final escapedTokens = _queryTokens.map(RegExp.escape).join('|');
    final regex = RegExp(escapedTokens, caseSensitive: false);

    int start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: baseStyle.copyWith(
          backgroundColor: markBg,
          color: markFg,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }
}

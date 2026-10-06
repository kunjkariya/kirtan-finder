/// KirtanLine model representing a single poetic line and verse marker.
class KirtanLine {
  final int id;
  final int kirtanId;
  final int lineNumber;
  final int verseNumber;
  final bool isTitleLine;
  final bool isVerseEnd;
  final String lineText;
  final String? verseMarker;

  const KirtanLine({
    required this.id,
    required this.kirtanId,
    required this.lineNumber,
    required this.verseNumber,
    required this.isTitleLine,
    required this.isVerseEnd,
    required this.lineText,
    this.verseMarker,
  });

  factory KirtanLine.fromMap(Map<String, dynamic> map) {
    return KirtanLine(
      id: map['id'] as int,
      kirtanId: map['kirtan_id'] as int,
      lineNumber: map['line_number'] as int,
      verseNumber: map['verse_number'] as int,
      isTitleLine: (map['is_title_line'] as int? ?? 0) == 1,
      isVerseEnd: (map['is_verse_end'] as int? ?? 0) == 1,
      lineText: map['line_text'] as String,
      verseMarker: map['verse_marker'] as String?,
    );
  }
}

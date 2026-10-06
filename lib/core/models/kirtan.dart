import 'kirtan_line.dart';

/// Full Kirtan model representing a complete devotional song.
class Kirtan {
  final int id;
  final String kirtanUid;
  final String uniqueKirtanId;
  final int partId;
  final int chapterId;
  final int partNumber;
  final int chapterNumber;
  final String? chapterTitle;
  final int kirtanNumber;
  final int oldPage;
  final String raag;
  final String raagNormalized;
  final String titleHi;
  final String titleEn;
  final String rawFirstLine;
  final String fullText;
  final String? youtubeUrl;
  final String sourceFilename;
  final String sourceAnchor;
  final String searchIdRaw;
  final int lineCount;
  final int verseCount;
  final int orderNum;

  // Lazily loaded or joined lines
  final List<KirtanLine> lines;

  const Kirtan({
    required this.id,
    required this.kirtanUid,
    this.uniqueKirtanId = '',
    required this.partId,
    required this.chapterId,
    required this.partNumber,
    required this.chapterNumber,
    this.chapterTitle,
    required this.kirtanNumber,
    required this.oldPage,
    required this.raag,
    required this.raagNormalized,
    required this.titleHi,
    required this.titleEn,
    required this.rawFirstLine,
    required this.fullText,
    this.youtubeUrl,
    required this.sourceFilename,
    required this.sourceAnchor,
    required this.searchIdRaw,
    required this.lineCount,
    required this.verseCount,
    required this.orderNum,
    this.lines = const [],
  });

  factory Kirtan.fromMap(Map<String, dynamic> map, {List<KirtanLine> lines = const []}) {
    final rawId = map['id'] as int;
    final orderNum = map['order_num'] as int? ?? rawId;
    final uId = map['unique_kirtan_id'] as String? ?? 'n$orderNum';

    return Kirtan(
      id: rawId,
      kirtanUid: map['kirtan_uid'] as String,
      uniqueKirtanId: uId,
      partId: map['part_id'] as int,
      chapterId: map['chapter_id'] as int,
      partNumber: map['part_number'] as int,
      chapterNumber: map['chapter_number'] as int,
      chapterTitle: (map['chapter_title'] as String?) ?? (map['chapter_title_hi'] as String?),
      kirtanNumber: map['kirtan_number'] as int,
      oldPage: map['old_page'] as int,
      raag: map['raag'] as String,
      raagNormalized: map['raag_normalized'] as String,
      titleHi: map['title_hi'] as String,
      titleEn: map['title_en'] as String,
      rawFirstLine: map['raw_first_line'] as String,
      fullText: map['full_text'] as String,
      youtubeUrl: map['youtube_url'] as String?,
      sourceFilename: map['source_filename'] as String,
      sourceAnchor: map['source_anchor'] as String,
      searchIdRaw: map['search_id_raw'] as String,
      lineCount: map['line_count'] as int,
      verseCount: map['verse_count'] as int,
      orderNum: orderNum,
      lines: lines,
    );
  }

  Kirtan copyWith({List<KirtanLine>? lines, String? chapterTitle}) {
    return Kirtan(
      id: id,
      kirtanUid: kirtanUid,
      uniqueKirtanId: uniqueKirtanId,
      partId: partId,
      chapterId: chapterId,
      partNumber: partNumber,
      chapterNumber: chapterNumber,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      kirtanNumber: kirtanNumber,
      oldPage: oldPage,
      raag: raag,
      raagNormalized: raagNormalized,
      titleHi: titleHi,
      titleEn: titleEn,
      rawFirstLine: rawFirstLine,
      fullText: fullText,
      youtubeUrl: youtubeUrl,
      sourceFilename: sourceFilename,
      sourceAnchor: sourceAnchor,
      searchIdRaw: searchIdRaw,
      lineCount: lineCount,
      verseCount: verseCount,
      orderNum: orderNum,
      lines: lines ?? this.lines,
    );
  }
}

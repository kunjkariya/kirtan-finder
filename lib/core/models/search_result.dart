/// SearchResult model representing a single hit in Search 1 or Search 2.
class SearchResult {
  final int id;
  final String kirtanUid;
  final String uniqueKirtanId;
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
  final String sourceFilename;
  final String sourceAnchor;
  final String? matchingSnippet;
  final double? rank;

  const SearchResult({
    required this.id,
    required this.kirtanUid,
    this.uniqueKirtanId = '',
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
    required this.sourceFilename,
    required this.sourceAnchor,
    this.matchingSnippet,
    this.rank,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'] as int;
    final orderNum = map['order_num'] as int? ?? rawId;
    final uId = map['unique_kirtan_id'] as String? ?? 'n$orderNum';

    return SearchResult(
      id: rawId,
      kirtanUid: map['kirtan_uid'] as String,
      uniqueKirtanId: uId,
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
      sourceFilename: map['source_filename'] as String,
      sourceAnchor: map['source_anchor'] as String,
      matchingSnippet: map['matching_snippet'] as String?,
      rank: (map['rank'] as num?)?.toDouble(),
    );
  }
}

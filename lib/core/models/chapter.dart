/// Chapter model representing one of the 409 chapters in Kirtan Sangrah.
class Chapter {
  final int id;
  final String chapterUid;
  final int partId;
  final int partNumber;
  final int chapterNumber;
  final String titleHi;
  final String? titleEn;
  final String? subtitleHi;
  final String sourceFilename;
  final int orderNum;

  const Chapter({
    required this.id,
    required this.chapterUid,
    required this.partId,
    required this.partNumber,
    required this.chapterNumber,
    required this.titleHi,
    this.titleEn,
    this.subtitleHi,
    required this.sourceFilename,
    required this.orderNum,
  });

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as int,
      chapterUid: map['chapter_uid'] as String,
      partId: map['part_id'] as int,
      partNumber: map['part_number'] as int,
      chapterNumber: map['chapter_number'] as int,
      titleHi: map['title_hi'] as String,
      titleEn: map['title_en'] as String?,
      subtitleHi: map['subtitle_hi'] as String?,
      sourceFilename: map['source_filename'] as String,
      orderNum: map['order_num'] as int,
    );
  }
}

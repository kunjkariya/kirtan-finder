/// Part model representing one of the 4 canonical divisions of Kirtan Sangrah.
class Part {
  final int id;
  final int partNumber;
  final String nameHi;
  final String nameEn;
  final int orderNum;

  const Part({
    required this.id,
    required this.partNumber,
    required this.nameHi,
    required this.nameEn,
    required this.orderNum,
  });

  factory Part.fromMap(Map<String, dynamic> map) {
    return Part(
      id: map['id'] as int,
      partNumber: map['part_number'] as int,
      nameHi: map['name_hi'] as String,
      nameEn: map['name_en'] as String,
      orderNum: map['order_num'] as int,
    );
  }
}

/// Filter options for restricting queries to a specific part.
enum PartFilter {
  all(null, 'सभी भाग (All)', 'All Parts'),
  part1(1, 'भाग १', 'Part 1'),
  part2(2, 'भाग २', 'Part 2'),
  part3(3, 'भाग ३', 'Part 3'),
  part4(4, 'भाग ४', 'Part 4');

  final int? partNumber;
  final String labelHi;
  final String labelEn;

  const PartFilter(this.partNumber, this.labelHi, this.labelEn);
}

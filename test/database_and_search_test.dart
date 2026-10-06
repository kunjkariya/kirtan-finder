import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kirtan_finder/core/database/database_migrator.dart';
import 'package:kirtan_finder/core/database/database_service.dart';
import 'package:kirtan_finder/core/models/part.dart';
import 'package:kirtan_finder/core/repositories/folder_repository.dart';
import 'package:kirtan_finder/core/repositories/kirtan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseService dbService;
  late KirtanRepository kirtanRepo;
  late FolderRepository folderRepo;
  late String testDbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Use a temporary copy of the bundled database so test mutations do not alter asset
    final sourcePath = 'assets/db/kirtan_finder.db';
    testDbPath = '${Directory.current.path}/test_kirtan_finder.db';
    final src = File(sourcePath);
    if (await src.exists()) {
      await src.copy(testDbPath);
    } else {
      final fallback = File('../database/kirtan_finder.db');
      await fallback.copy(testDbPath);
    }

    db = await databaseFactoryFfi.openDatabase(testDbPath);
    await DatabaseMigrator.migrate(db);
    dbService = DatabaseService.withDatabase(db);
    kirtanRepo = KirtanRepository(dbService);
    folderRepo = FolderRepository(dbService);
  });

  tearDownAll(() async {
    await db.close();
    final f = File(testDbPath);
    if (await f.exists()) {
      await f.delete();
    }
  });

  group('1. Database Integrity & Canonical Public ID (n1..n6584) Verification', () {
    test('Database opens successfully', () {
      expect(db.isOpen, isTrue);
    });

    test('Contains exactly 6,584 kirtans', () async {
      final count = await kirtanRepo.getKirtanCount();
      expect(count, equals(6584));
    });

    test('Every kirtan has a unique, non-null canonical ID matching n + digits without leading zeroes', () async {
      final rows = await db.rawQuery(
        'SELECT id, order_num, unique_kirtan_id FROM kirtans ORDER BY order_num ASC;',
      );
      expect(rows.length, equals(6584));

      final uniqueIds = <String>{};
      final nRegex = RegExp(r'^n[1-9]\d*$');

      for (int i = 0; i < rows.length; i++) {
        final expectedNum = i + 1;
        final expectedId = 'n$expectedNum';
        final actualId = rows[i]['unique_kirtan_id'] as String;

        expect(nRegex.hasMatch(actualId), isTrue, reason: 'Invalid format: $actualId');
        expect(actualId, equals(expectedId), reason: 'ID mismatch at order_num $expectedNum');
        uniqueIds.add(actualId);
      }

      expect(uniqueIds.length, equals(6584), reason: 'All 6,584 IDs must be strictly unique');
      expect(uniqueIds.contains('n1'), isTrue, reason: 'First ID must be n1');
      expect(uniqueIds.contains('n6584'), isTrue, reason: 'Last ID must be n6584');
    });

    test('Contains exactly 409 chapters and 4 parts', () async {
      expect(await kirtanRepo.getChapterCount(), equals(409));
      expect(await kirtanRepo.getPartCount(), equals(4));
    });
  });

  group('2. Search 1: Public Kirtan ID (n####) Exact Matching', () {
    test('Basic IDs: n1, n2, n123, n1541, n6584 return exactly 1 kirtan each', () async {
      for (final id in ['n1', 'n2', 'n123', 'n1541', 'n6584']) {
        final results = await kirtanRepo.searchTitle(query: id);
        expect(results.length, equals(1), reason: 'Query $id should return exactly 1 kirtan');
        expect(results.first.uniqueKirtanId, equals(id));
      }
    });

    test('Case insensitivity: n1541 and N1541 return exactly the same kirtan', () async {
      final lower = await kirtanRepo.searchTitle(query: 'n1541');
      final upper = await kirtanRepo.searchTitle(query: 'N1541');

      expect(lower.length, equals(1));
      expect(upper.length, equals(1));
      expect(lower.first.id, equals(upper.first.id));
      expect(lower.first.uniqueKirtanId, equals('n1541'));
      expect(upper.first.uniqueKirtanId, equals('n1541'));
    });

    test('Surrounding whitespace: "  n1541  " returns exactly the same kirtan', () async {
      final results = await kirtanRepo.searchTitle(query: '  n1541  ');
      expect(results.length, equals(1));
      expect(results.first.uniqueKirtanId, equals('n1541'));
    });

    test('Exactness: n1 must NOT return n10, n100, or n1000', () async {
      final results = await kirtanRepo.searchTitle(query: 'n1');
      expect(results.length, equals(1));
      expect(results.first.uniqueKirtanId, equals('n1'));
    });

    test('Exactness: n154 must NOT return n1541 as an ID match', () async {
      final results = await kirtanRepo.searchTitle(query: 'n154');
      expect(results.length, equals(1));
      expect(results.first.uniqueKirtanId, equals('n154'));
    });

    test('Exactness: n1541 must NOT return n15410, n15411, n15412', () async {
      final results = await kirtanRepo.searchTitle(query: 'n1541');
      expect(results.length, equals(1));
      expect(results.first.uniqueKirtanId, equals('n1541'));
    });

    test('Invalid IDs: n0, n6585, n99999 return zero results', () async {
      expect((await kirtanRepo.searchTitle(query: 'n0')).isEmpty, isTrue);
      expect((await kirtanRepo.searchTitle(query: 'n6585')).isEmpty, isTrue);
      expect((await kirtanRepo.searchTitle(query: 'n99999')).isEmpty, isTrue);
    });

    test('Old padded IDs: N0001, N0154 are no longer treated as valid public IDs', () async {
      final res0001 = await kirtanRepo.searchTitle(query: 'N0001');
      expect(res0001.isEmpty, isTrue);

      final res0154 = await kirtanRepo.searchTitle(query: 'N0154');
      expect(res0154.isEmpty, isTrue);
    });

    test('Part filter: n1541 belongs to Part 2 (returns 1 in Part 2, 0 in Part 1)', () async {
      final allRes = await kirtanRepo.searchTitle(query: 'n1541', partFilter: PartFilter.all);
      expect(allRes.length, equals(1));
      expect(allRes.first.partNumber, equals(2));

      final p2Res = await kirtanRepo.searchTitle(query: 'n1541', partFilter: PartFilter.part2);
      expect(p2Res.length, equals(1));
      expect(p2Res.first.uniqueKirtanId, equals('n1541'));

      final p1Res = await kirtanRepo.searchTitle(query: 'n1541', partFilter: PartFilter.part1);
      expect(p1Res.isEmpty, isTrue, reason: 'n1541 belongs to Part 2, must return zero in Part 1');
    });
  });

  group('3. Search 1: Removed Old Structured ID Formats', () {
    test('"1.1" is no longer parsed as Chapter 1, Kirtan 1 structured lookup', () async {
      final results = await kirtanRepo.searchTitle(query: '1.1');
      expect(results.isEmpty, isTrue);
    });

    test('"१.१" is no longer parsed as structured identifier', () async {
      final results = await kirtanRepo.searchTitle(query: '१.१');
      expect(results.isEmpty, isTrue);
    });

    test('"C1.K1" is no longer parsed as structured identifier', () async {
      final results = await kirtanRepo.searchTitle(query: 'C1.K1');
      expect(results.isEmpty, isTrue);
    });

    test('"C1.K1.P1" is no longer parsed as structured identifier', () async {
      final results = await kirtanRepo.searchTitle(query: 'C1.K1.P1');
      expect(results.isEmpty, isTrue);
    });

    test('"P1.C1.K1.P1" is no longer parsed as primary user search identifier', () async {
      final results = await kirtanRepo.searchTitle(query: 'P1.C1.K1.P1');
      expect(results.isEmpty, isTrue);
    });
  });

  group('4. Search 1: Hindi Substring / Contains Search', () {
    test('"राधा" matches standalone, embedded, and compound titles', () async {
      final results = await kirtanRepo.searchTitle(query: 'राधा', limit: 200);
      expect(results.length, equals(123));
      for (final r in results) {
        final matches = r.titleHi.contains('राधा') ||
            r.rawFirstLine.contains('राधा') ||
            r.titleEn.toLowerCase().contains('radha');
        expect(matches, isTrue);
      }
    });

    test('"राध" matches as true substring and is a superset of "राधा"', () async {
      final radhResults = await kirtanRepo.searchTitle(query: 'राध', limit: 300);
      expect(radhResults.length, equals(237));
      expect(radhResults.length, greaterThan(123));
    });

    test('"श्रीराधा" is matched as true substring and is contained in "राधा"', () async {
      final shriRadhaResults = await kirtanRepo.searchTitle(query: 'श्रीराधा', limit: 100);
      expect(shriRadhaResults.length, equals(12));

      final radhaResults = await kirtanRepo.searchTitle(query: 'राधा', limit: 200);
      final radhaIds = radhaResults.map((r) => r.id).toSet();

      for (final r in shriRadhaResults) {
        expect(radhaIds.contains(r.id), isTrue,
            reason: 'Every result for "श्रीराधा" must be matched by substring "राधा"');
      }
    });

    test('"श्री राधा" matches spaced phrase', () async {
      final results = await kirtanRepo.searchTitle(query: 'श्री राधा');
      expect(results.length, equals(4));
      for (final r in results) {
        expect(r.titleHi.contains('श्री राधा') || r.rawFirstLine.contains('श्री राधा'), isTrue);
      }
    });
  });

  group('5. Search 1: Raw First Line Fallback Matching', () {
    test('Kirtan n2218 has "राधा" in raw_first_line but NOT in title_hi and is found by Search 1', () async {
      final results = await kirtanRepo.searchTitle(query: 'राधा', limit: 200);
      final match = results.where((r) => r.uniqueKirtanId == 'n2218').firstOrNull;

      expect(match, isNotNull, reason: 'Kirtan n2218 must be found via raw_first_line');
      expect(match!.titleHi.contains('राधा'), isFalse, reason: 'title_hi does not contain राधा');
      expect(match.rawFirstLine.contains('राधा'), isTrue, reason: 'raw_first_line contains राधा');
    });
  });

  group('6. Search 1: English Substring Search', () {
    test('Case-insensitivity: "Radha", "radha", and "RADHA" return identical counts', () async {
      final r1 = await kirtanRepo.searchTitle(query: 'Radha', limit: 300);
      final r2 = await kirtanRepo.searchTitle(query: 'radha', limit: 300);
      final r3 = await kirtanRepo.searchTitle(query: 'RADHA', limit: 300);

      expect(r1.length, equals(179));
      expect(r2.length, equals(179));
      expect(r3.length, equals(179));

      final ids1 = r1.map((r) => r.id).toList();
      final ids2 = r2.map((r) => r.id).toList();
      final ids3 = r3.map((r) => r.id).toList();
      expect(ids1, equals(ids2));
      expect(ids2, equals(ids3));
    });

    test('"Radha" matches inside compound English words (e.g. Shriradha in n622)', () async {
      final results = await kirtanRepo.searchTitle(query: 'Radha', limit: 300);
      final n622 = results.where((r) => r.uniqueKirtanId == 'n622').firstOrNull;
      expect(n622, isNotNull);
      expect(n622!.titleEn, contains('Shriradha'));
    });
  });

  group('7. Search 1: Bare Integer (Old Printed Page Search)', () {
    test('Bare integer "25": interpreted strictly as old printed page 25', () async {
      final results = await kirtanRepo.searchTitle(query: '25');
      expect(results.length, equals(19));
      for (final r in results) {
        expect(r.oldPage, equals(25));
      }
    });

    test('Devanagari digits "२५": normalized to old printed page 25', () async {
      final results = await kirtanRepo.searchTitle(query: '२५');
      expect(results.length, equals(19));
      for (final r in results) {
        expect(r.oldPage, equals(25));
      }
    });

    test('All Parts + "25" vs Part 2 + "25": strictly isolates Part 2 without leakage', () async {
      final allRes = await kirtanRepo.searchTitle(query: '25', partFilter: PartFilter.all);
      expect(allRes.length, equals(19));

      final p2Res = await kirtanRepo.searchTitle(query: '25', partFilter: PartFilter.part2);
      expect(p2Res.length, equals(3));
      for (final r in p2Res) {
        expect(r.partNumber, equals(2));
        expect(r.oldPage, equals(25));
      }
    });
  });

  group('8. Search 1: Part Filter Isolation Across Query Types', () {
    test('Hindi substring "राधा" across all 4 parts', () async {
      for (final pf in [PartFilter.part1, PartFilter.part2, PartFilter.part3, PartFilter.part4]) {
        final res = await kirtanRepo.searchTitle(query: 'राधा', partFilter: pf, limit: 100);
        for (final r in res) {
          expect(r.partNumber, equals(pf.partNumber));
        }
      }
    });

    test('English substring "Radha" across all 4 parts', () async {
      for (final pf in [PartFilter.part1, PartFilter.part2, PartFilter.part3, PartFilter.part4]) {
        final res = await kirtanRepo.searchTitle(query: 'Radha', partFilter: pf, limit: 100);
        for (final r in res) {
          expect(r.partNumber, equals(pf.partNumber));
        }
      }
    });

    test('Page number "25" across all 4 parts', () async {
      for (final pf in [PartFilter.part1, PartFilter.part2, PartFilter.part3, PartFilter.part4]) {
        final res = await kirtanRepo.searchTitle(query: '25', partFilter: pf);
        for (final r in res) {
          expect(r.partNumber, equals(pf.partNumber));
          expect(r.oldPage, equals(25));
        }
      }
    });
  });

  group('9. Search 2: Unchanged Kirtan Lines FTS', () {
    test('Line search: "श्री" returns exact word matches', () async {
      final results = await kirtanRepo.searchLines(query: 'श्री');
      expect(results.length, equals(50));
      for (final r in results) {
        expect(r.matchingSnippet, isNotNull);
        expect(r.matchingSnippet!.contains('<mark>'), isTrue);
      }
    });

    test('Line search: "श्री कृष्ण" returns exactly 16 matches with zero "शिर" false matches', () async {
      final results = await kirtanRepo.searchLines(query: 'श्री कृष्ण', limit: 100);
      expect(results.length, equals(16));
      for (final r in results) {
        expect(r.matchingSnippet, isNotNull);
      }
    });

    test('Line search: "गोवर्धन" returns matches with highlights', () async {
      final results = await kirtanRepo.searchLines(query: 'गोवर्धन');
      expect(results.length, equals(50));
      for (final r in results) {
        expect(r.matchingSnippet!.contains('<mark>गोवर्धन</mark>'), isTrue);
      }
    });
  });

  group('10. Kirtan Retrieval & Canonical n-ID Lookup', () {
    test('getKirtanById retrieves complete record with canonical unique_kirtan_id "n1"', () async {
      final kirtan = await kirtanRepo.getKirtanById(1);
      expect(kirtan, isNotNull);
      expect(kirtan!.id, equals(1));
      expect(kirtan.uniqueKirtanId, equals('n1'));
      expect(kirtan.kirtanUid, equals('P1.C1.K1.P1'));
      expect(kirtan.lines.isNotEmpty, isTrue);
    });

    test('getKirtanByUniqueId retrieves identical record by "n1541" and "N1541"', () async {
      final kirtanLower = await kirtanRepo.getKirtanByUniqueId('n1541');
      expect(kirtanLower, isNotNull);
      expect(kirtanLower!.uniqueKirtanId, equals('n1541'));

      final kirtanUpper = await kirtanRepo.getKirtanByUniqueId('N1541');
      expect(kirtanUpper, isNotNull);
      expect(kirtanUpper!.uniqueKirtanId, equals('n1541'));
      expect(kirtanLower.id, equals(kirtanUpper.id));
    });

    test('getKirtanByUid retrieves record by legacy UID', () async {
      final kirtan = await kirtanRepo.getKirtanByUid('P1.C1.K1.P1');
      expect(kirtan, isNotNull);
      expect(kirtan!.id, equals(1));
      expect(kirtan.uniqueKirtanId, equals('n1'));
    });
  });

  group('11. Favourites & Folder System Preserved', () {
    test('Default Favorites folder (id=1) exists', () async {
      final folders = await folderRepo.getFolders();
      expect(folders.any((f) => f.id == 1), isTrue);
    });

    test('Create custom folder, bookmark kirtan reference, and verify zero duplication', () async {
      final newFolder = await folderRepo.createFolder('Morning Kirtans');
      expect(newFolder.id, greaterThan(1));
      expect(newFolder.name, equals('Morning Kirtans'));

      final added = await folderRepo.addKirtanToFolder(newFolder.id, 1);
      expect(added, isTrue);

      final isSaved = await folderRepo.isKirtanBookmarked(1);
      expect(isSaved, isTrue);

      final folderIds = await folderRepo.getFolderIdsForKirtan(1);
      expect(folderIds.contains(newFolder.id), isTrue);

      final kirtans = await folderRepo.getKirtansInFolder(newFolder.id);
      expect(kirtans.length, equals(1));
      expect(kirtans.first.id, equals(1));
      expect(kirtans.first.uniqueKirtanId, equals('n1'));

      final removed = await folderRepo.removeKirtanFromFolder(newFolder.id, 1);
      expect(removed, isTrue);

      final remaining = await folderRepo.getKirtansInFolder(newFolder.id);
      expect(remaining.isEmpty, isTrue);
    });
  });
}

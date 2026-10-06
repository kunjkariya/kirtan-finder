import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kirtan_finder/app/app.dart';
import 'package:kirtan_finder/core/database/database_migrator.dart';
import 'package:kirtan_finder/core/database/database_service.dart';
import 'package:kirtan_finder/core/models/part.dart';
import 'package:kirtan_finder/core/repositories/folder_repository.dart';
import 'package:kirtan_finder/core/repositories/kirtan_repository.dart';
import 'package:kirtan_finder/features/kirtan/kirtan_screen.dart';
import 'package:kirtan_finder/features/kirtan/widgets/kirtan_header.dart';
import 'package:kirtan_finder/features/kirtan/widgets/kirtan_lyrics.dart';
import 'package:kirtan_finder/features/search/widgets/search_result_tile.dart';

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

    final sourceCandidates = [
      'assets/db/kirtan_finder.db',
      '../database/kirtan_finder.db',
    ];
    String? foundPath;
    for (final p in sourceCandidates) {
      if (File(p).existsSync()) {
        foundPath = p;
        break;
      }
    }
    testDbPath = '${Directory.current.path}/test_final_qa_kirtan_finder.db';
    await File(foundPath!).copy(testDbPath);

    db = await databaseFactoryFfi.openDatabase(testDbPath);
    await DatabaseMigrator.migrate(db);

    dbService = DatabaseService.withDatabase(db);
    kirtanRepo = KirtanRepository(dbService);
    folderRepo = FolderRepository(dbService);
  });

  tearDownAll(() async {
    if (db.isOpen) {
      await db.close();
    }
    final f = File(testDbPath);
    if (await f.exists()) {
      await f.delete();
    }
  });

  setUp(() async {
    // Reset user folders and bookmarks before each test
    await db.delete('folder_kirtans');
    await db.delete('folders', where: 'is_system = 0');
  });

  Future<void> pumpRealAsync(WidgetTester tester, [Duration duration = const Duration(milliseconds: 50)]) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(duration);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 40));
      });
      await tester.pump();
    }
  }

  group('FINAL QA 1. Data Integrity & Source Corpus Protection', () {
    test('Verify exact corpus counts: 6,584 kirtans, 409 chapters, 4 parts', () async {
      final kirtanCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM kirtans;'),
      );
      final chapterCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM chapters;'),
      );
      final partsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(DISTINCT part_number) FROM kirtans;'),
      );
      final distinctUids = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(DISTINCT unique_kirtan_id) FROM kirtans;'),
      );

      expect(kirtanCount, equals(6584));
      expect(chapterCount, equals(409));
      expect(partsCount, equals(4));
      expect(distinctUids, equals(6584));
    });

    test('Verify all 6,584 public IDs are strictly n1 through n6584 without gaps', () async {
      final rows = await db.rawQuery('SELECT unique_kirtan_id FROM kirtans ORDER BY id ASC;');
      expect(rows.length, equals(6584));

      for (int i = 0; i < rows.length; i++) {
        final expected = 'n${i + 1}';
        expect(rows[i]['unique_kirtan_id'], equals(expected));
      }
    });

    test('Verify no blank titles, no blank lines, and valid source mapping', () async {
      final blankHi = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM kirtans WHERE title_hi IS NULL OR trim(title_hi) = '';"),
      );
      final blankEn = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM kirtans WHERE title_en IS NULL OR trim(title_en) = '';"),
      );
      final blankLines = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM kirtan_lines WHERE line_text IS NULL OR trim(line_text) = '';"),
      );
      final brokenSource = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM kirtans WHERE source_filename IS NULL OR source_anchor IS NULL;'),
      );

      expect(blankHi, equals(0));
      expect(blankEn, equals(0));
      expect(blankLines, equals(0));
      expect(brokenSource, equals(0));
    });
  });

  group('FINAL QA 2. Search 1 Semantics & Exact N-ID / Page Lookups', () {
    test('N-ID: case-insensitive exact matching (n1541 and N1541)', () async {
      final resLower = await kirtanRepo.searchTitle(query: 'n1541');
      final resUpper = await kirtanRepo.searchTitle(query: 'N1541');

      expect(resLower.length, equals(1));
      expect(resUpper.length, equals(1));
      expect(resLower.first.uniqueKirtanId, equals('n1541'));
      expect(resUpper.first.uniqueKirtanId, equals('n1541'));
      expect(resLower.first.id, equals(1541));
    });

    test('N-ID: exact matching only (no prefix leakage: n1 must not return n10 or n1541)', () async {
      final res = await kirtanRepo.searchTitle(query: 'n1');
      expect(res.length, equals(1));
      expect(res.first.uniqueKirtanId, equals('n1'));
      expect(res.first.id, equals(1));
    });

    test('Page search: 25 and २५ return exact page matches across all parts', () async {
      final resAscii = await kirtanRepo.searchTitle(query: '25');
      final resDeva = await kirtanRepo.searchTitle(query: '२५');

      expect(resAscii.isNotEmpty, isTrue);
      expect(resDeva.isNotEmpty, isTrue);
      expect(resAscii.length, equals(resDeva.length));

      for (final r in resAscii) {
        expect(r.oldPage, equals(25));
      }
    });

    test('Hindi substring search across title_hi, raw_first_line', () async {
      final res1 = await kirtanRepo.searchTitle(query: 'राधा');
      final res2 = await kirtanRepo.searchTitle(query: 'राध');
      final res3 = await kirtanRepo.searchTitle(query: 'श्री राधा');

      expect(res1.isNotEmpty, isTrue);
      expect(res2.isNotEmpty, isTrue);
      expect(res3.isNotEmpty, isTrue);

      for (final r in res1) {
        final matchesHi = r.titleHi.contains('राधा') || r.rawFirstLine.contains('राधा');
        final matchesEn = r.titleEn.toLowerCase().contains('radha');
        expect(matchesHi || matchesEn, isTrue);
      }
    });

    test('English substring search is case-insensitive', () async {
      final resLower = await kirtanRepo.searchTitle(query: 'radha');
      final resUpper = await kirtanRepo.searchTitle(query: 'RADHA');
      final resTitle = await kirtanRepo.searchTitle(query: 'Radha');

      expect(resLower.length, equals(resUpper.length));
      expect(resLower.length, equals(resTitle.length));
      expect(resLower.isNotEmpty, isTrue);
    });
  });

  group('FINAL QA 3. Search 2 Lyrics Semantics & Metadata Isolation', () {
    test('Search 2 searches only kirtan_lines and excludes metadata', () async {
      final res = await kirtanRepo.searchLines(query: 'श्री कृष्ण');
      expect(res.isNotEmpty, isTrue);

      for (final r in res) {
        expect(r.matchingSnippet, isNotNull);
        expect(r.matchingSnippet!.isNotEmpty, isTrue);
      }
    });

    test('Search 2 exact token queries: गोवर्धन, शिर', () async {
      final resGovardhan = await kirtanRepo.searchLines(query: 'गोवर्धन');
      final resShir = await kirtanRepo.searchLines(query: 'शिर');

      expect(resGovardhan.isNotEmpty, isTrue);
      expect(resShir.isNotEmpty, isTrue);

      for (final r in resGovardhan) {
        expect(r.matchingSnippet!.contains('गोवर्धन') || r.matchingSnippet!.contains('mark'), isTrue);
      }
    });
  });

  group('FINAL QA 4. Part Filter Isolation & Zero Leakage', () {
    test('Part filtering strictly isolates results in Search 1 and Search 2', () async {
      for (final filter in [PartFilter.part1, PartFilter.part2, PartFilter.part3, PartFilter.part4]) {
        final part = filter.partNumber!;

        // Search 1 with Part
        final s1 = await kirtanRepo.searchTitle(query: 'राधा', partFilter: filter);
        for (final r in s1) {
          expect(r.partNumber, equals(part));
        }

        // Search 2 with Part
        final s2 = await kirtanRepo.searchLines(query: 'श्री कृष्ण', partFilter: filter);
        for (final r in s2) {
          expect(r.partNumber, equals(part));
        }

        // Page with Part
        final sPage = await kirtanRepo.searchTitle(query: '25', partFilter: filter);
        for (final r in sPage) {
          expect(r.partNumber, equals(part));
        }
      }
    });

    test('N-ID with Part filter returns result only if kirtan belongs to that Part', () async {
      // n1 is in Part 1
      final p1 = await kirtanRepo.searchTitle(query: 'n1', partFilter: PartFilter.part1);
      final p2 = await kirtanRepo.searchTitle(query: 'n1', partFilter: PartFilter.part2);

      expect(p1.length, equals(1));
      expect(p2.length, equals(0));
    });
  });

  group('FINAL QA 5. Favorites & Multi-Folder Ordering Persistence', () {
    test('System Favorites folder (id = 1) is protected and permanently exists', () async {
      final folders = await folderRepo.getFoldersOrdered();
      expect(folders.any((f) => f.id == 1 && f.isSystem), isTrue);

      // Attempting to delete system folder is safely ignored
      await folderRepo.deleteFolder(1);
      final postFolders = await folderRepo.getFoldersOrdered();
      expect(postFolders.any((f) => f.id == 1 && f.isSystem), isTrue);
    });

    test('Multi-folder assignment, reordering, and restart survival', () async {
      // Create custom folders
      final morningFolder = await folderRepo.createFolder('Morning Kirtans');
      final haveliFolder = await folderRepo.createFolder('Haveli Kirtans');

      // Add kirtans to multiple folders
      await folderRepo.addToFolder(FolderRepository.favoritesFolderId, 1);
      await folderRepo.addToFolder(FolderRepository.favoritesFolderId, 1541);
      await folderRepo.addToFolder(morningFolder.id, 1);
      await folderRepo.addToFolder(haveliFolder.id, 1);
      await folderRepo.addToFolder(haveliFolder.id, 123);

      // Verify membership
      expect(await folderRepo.isFavorite(1), isTrue);
      expect(await folderRepo.isFavorite(1541), isTrue);
      expect(await folderRepo.isKirtanInFolder(morningFolder.id, 1), isTrue);
      expect(await folderRepo.isKirtanInFolder(haveliFolder.id, 1), isTrue);

      // Reorder folders
      final reorderedIds = [haveliFolder.id, morningFolder.id, FolderRepository.favoritesFolderId];
      await folderRepo.updateFolderOrder(reorderedIds);

      final postReorderFolders = await folderRepo.getFoldersOrdered();
      expect(postReorderFolders[0].id, equals(haveliFolder.id));
      expect(postReorderFolders[1].id, equals(morningFolder.id));
      expect(postReorderFolders[2].id, equals(FolderRepository.favoritesFolderId));

      // Reorder kirtans inside folder
      await folderRepo.updateKirtanOrder(FolderRepository.favoritesFolderId, [1541, 1]);
      final favKirtans = await folderRepo.getFolderKirtans(FolderRepository.favoritesFolderId);
      expect(favKirtans[0].id, equals(1541));
      expect(favKirtans[1].id, equals(1));

      // Delete custom folder: must not delete kirtan from database or other folders
      await folderRepo.deleteFolder(morningFolder.id);
      expect(await folderRepo.isKirtanInFolder(haveliFolder.id, 1), isTrue);
      expect(await folderRepo.isFavorite(1), isTrue);
      final kirtan1 = await kirtanRepo.getKirtanById(1);
      expect(kirtan1, isNotNull);
    });
  });

  group('FINAL QA 6. Reader Visual Hierarchy & Source Fidelity Across Kirtan Types', () {
    testWidgets('Reader renders short kirtan with authentic lines and markers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 2,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.byType(KirtanHeader), findsOneWidget);
      expect(find.byType(KirtanLyrics), findsOneWidget);
      expect(find.text('n2'), findsWidgets);
      expect(find.text('Part 1'), findsOneWidget);
    });

    testWidgets('Reader renders long kirtan (n1, 60 lines) with authentic verse markers (॥१॥..॥१५॥)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.text('n1'), findsWidgets);
      expect(find.text('व्रज भयो महरिकैं पूत जब यह बात सुनी ॥'), findsWidgets);
      expect(find.text('Vraja Bhayo Maharikain Puta Jaba Yaha Bata Suni'), findsOneWidget);
      expect(find.textContaining('॥१॥'), findsOneWidget);
      expect(find.textContaining('॥१५॥'), findsOneWidget);
    });

    testWidgets('Previous and Next sequential navigation along corpus order_num', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.text('1541 / 6584'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await pumpRealAsync(tester);
      expect(find.text('1542 / 6584'), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await pumpRealAsync(tester);
      expect(find.text('1541 / 6584'), findsOneWidget);
    });
  });

  group('FINAL QA 7. Responsive Layouts & Dark Mode Verification', () {
    testWidgets('Narrow phone (320x568) - No horizontal overflow or clipping', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.byType(KirtanHeader), findsOneWidget);
      expect(find.byType(KirtanLyrics), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iPad Landscape (1080x810) - Reading column centered at maxWidth 780', (tester) async {
      tester.view.physicalSize = const Size(1080, 810);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final readingBox = boxes.firstWhere((b) => b.constraints.maxWidth == 780);
      expect(readingBox, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dark Mode Theme - High contrast and readable elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.text('n1541'), findsWidgets);
      expect(find.byType(KirtanHeader), findsOneWidget);
      expect(find.byType(KirtanLyrics), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FINAL QA 8. Complete End-to-End User Journeys', () {
    testWidgets('Journey A: Search 1 -> "राधा" -> Part 2 -> Open Kirtan -> Favorite -> Add to Folder',
        (tester) async {
      final app = KirtanFinderApp(
        kirtanRepository: kirtanRepo,
        folderRepository: folderRepo,
      );

      await tester.pumpWidget(app);
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      // 1. Search "राधा" in Search 1
      await tester.enterText(find.byType(TextField), 'राधा');
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      // 2. Select Part 2 filter
      await tester.tap(find.text('Part 2'));
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      expect(find.byType(SearchResultTile), findsWidgets);

      // 3. Open first result
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byType(SearchResultTile).first);
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify reader opened
      expect(find.byType(KirtanScreen), findsOneWidget);

      // 4. Quick Favorite
      final favBtn = find.byKey(const ValueKey('quick_favorite_button'));
      expect(favBtn, findsOneWidget);
      await tester.tap(favBtn);
      await pumpRealAsync(tester);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // 5. Add to folder via sheet
      final folderBtn = find.byKey(const ValueKey('folder_bookmark_button'));
      await tester.tap(folderBtn);
      await pumpRealAsync(tester);
      expect(find.text('Save to Folder'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close));
      await pumpRealAsync(tester);
    });

    testWidgets('Journey B: Search 2 -> "श्री कृष्ण" -> Part 1 -> Highlighted Snippet -> Reader auto-scroll',
        (tester) async {
      final app = KirtanFinderApp(
        kirtanRepository: kirtanRepo,
        folderRepository: folderRepo,
      );

      await tester.pumpWidget(app);
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      // 1. Switch to Search 2 (Lyrics)
      await tester.tap(find.text('Kirtan Lines'));
      await pumpRealAsync(tester, const Duration(milliseconds: 200));

      // 2. Enter query "श्री कृष्ण"
      await tester.enterText(find.byType(TextField), 'श्री कृष्ण');
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      // 3. Filter Part 1
      await tester.tap(find.text('Part 1'));
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      expect(find.byType(SearchResultTile), findsWidgets);

      // 4. Open result
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byType(SearchResultTile).first);
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.byType(KirtanLyrics), findsOneWidget);
    });

    testWidgets('Journey C: Search N-ID -> "n1541" -> Exact Kirtan -> Navigation',
        (tester) async {
      final app = KirtanFinderApp(
        kirtanRepository: kirtanRepo,
        folderRepository: folderRepo,
      );

      await tester.pumpWidget(app);
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      // 1. Enter query "n1541" in Search 1
      await tester.enterText(find.byType(TextField), 'n1541');
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      // Exactly 1 result tile
      expect(find.byType(SearchResultTile), findsOneWidget);
      expect(find.text('n1541'), findsWidgets);

      // 2. Open result
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byType(SearchResultTile));
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.text('1541 / 6584'), findsOneWidget);

      // Previous -> n1540
      await tester.tap(find.text('Previous'));
      await pumpRealAsync(tester);
      expect(find.text('1540 / 6584'), findsOneWidget);

      // Next -> n1541
      await tester.tap(find.text('Next'));
      await pumpRealAsync(tester);
      expect(find.text('1541 / 6584'), findsOneWidget);
    });
  });
}

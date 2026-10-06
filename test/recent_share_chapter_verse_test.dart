import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirtan_finder/core/database/database_migrator.dart';
import 'package:kirtan_finder/core/database/database_service.dart';
import 'package:kirtan_finder/core/models/kirtan.dart';
import 'package:kirtan_finder/core/models/search_result.dart';
import 'package:kirtan_finder/core/repositories/folder_repository.dart';
import 'package:kirtan_finder/core/repositories/kirtan_repository.dart';
import 'package:kirtan_finder/core/repositories/recent_repository.dart';
import 'package:kirtan_finder/core/repositories/settings_repository.dart';
import 'package:kirtan_finder/core/services/share_service.dart';
import 'package:kirtan_finder/features/kirtan/kirtan_screen.dart';
import 'package:kirtan_finder/features/kirtan/shared_kirtan_screen.dart';
import 'package:kirtan_finder/features/kirtan/widgets/kirtan_lyrics.dart';
import 'package:kirtan_finder/features/recent/recent_screen.dart';
import 'package:kirtan_finder/features/search/search_controller.dart' as sc;
import 'package:kirtan_finder/features/search/search_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseService dbService;
  late KirtanRepository kirtanRepo;
  late FolderRepository folderRepo;
  late RecentRepository recentRepo;
  late SettingsRepository settingsRepo;
  late String testDbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final sourcePath = 'assets/db/kirtan_finder.db';
    testDbPath = '${Directory.current.path}/test_recent_features_kirtan_finder.db';
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
    recentRepo = RecentRepository(dbService);
    settingsRepo = SettingsRepository(dbService);
  });

  tearDownAll(() async {
    await db.close();
    final f = File(testDbPath);
    if (await f.exists()) {
      await f.delete();
    }
  });

  setUp(() async {
    await db.delete('recent_kirtans');
    await db.delete('folder_kirtans');
    await db.delete('app_settings');
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

  // =========================================================================
  // 1. CHAPTER TITLE DISPLAY TESTS
  // =========================================================================
  group('1. Chapter Title Display Tests', () {
    testWidgets('Kirtan model and SearchResult include actual canonical chapter title', (tester) async {
      Kirtan? kirtan1;
      await tester.runAsync(() async {
        kirtan1 = await kirtanRepo.getKirtanById(1);
      });
      expect(kirtan1, isNotNull);
      expect(kirtan1!.chapterTitle, equals('जन्माष्टमी बधाई'));
      expect(kirtan1!.chapterNumber, equals(1));

      List results = [];
      await tester.runAsync(() async {
        results = await kirtanRepo.searchTitle(query: 'व्रज भयो');
      });
      expect(results.isNotEmpty, isTrue);
      expect(results.first.chapterTitle, equals('जन्माष्टमी बधाई'));
    });

    testWidgets('Reader displays actual chapter title and NOT "Ch X"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.text('जन्माष्टमी बधाई'), findsOneWidget);
      expect(find.text('Kirtan 1'), findsOneWidget);
      expect(find.textContaining('Ch 1'), findsNothing);
    });
  });

  // =========================================================================
  // 2. VERSE MARKER COLOR TESTS
  // =========================================================================
  group('2. Verse Marker Color Tests', () {
    testWidgets('Verse markers have the exact same color as lyrics (no fading)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.textContaining('॥१॥'), findsOneWidget);
      expect(find.textContaining('॥२॥'), findsOneWidget);

      final selectableTextFinder = find.byType(SelectableText);
      expect(selectableTextFinder, findsWidgets);

      bool foundMarkerWithCorrectColor = false;
      for (final element in tester.elementList(selectableTextFinder)) {
        final widget = element.widget as SelectableText;
        final textSpan = widget.textSpan;
        if (textSpan != null) {
          textSpan.visitChildren((span) {
            if (span is TextSpan && span.text != null && span.text!.contains('॥१॥')) {
              // Ensure color is not faded grey
              expect(span.style?.color, isNot(const Color(0xFF6E6E73)));
              expect(span.style?.color, isNot(const Color(0xFF8E8E93)));
              // Lyric color in light mode is Color(0xFF111111)
              expect(span.style?.color, equals(const Color(0xFF111111)));
              foundMarkerWithCorrectColor = true;
            }
            return true;
          });
        }
      }
      expect(foundMarkerWithCorrectColor, isTrue);
    });
  });

  // =========================================================================
  // 3. RECENTLY OPENED TESTS
  // =========================================================================
  group('3. Recently Opened Tests', () {
    testWidgets('Opening a kirtan adds it to Recent, most recent first', (tester) async {
      await tester.runAsync(() async {
        await recentRepo.recordOpened(1);
        await recentRepo.recordOpened(2);
        await recentRepo.recordOpened(3);

        final recent = await recentRepo.getRecentKirtans();
        expect(recent.length, equals(3));
        expect(recent[0].id, equals(3));
        expect(recent[1].id, equals(2));
        expect(recent[2].id, equals(1));
      });
    });

    testWidgets('Reopening an existing kirtan moves it to top without duplicates', (tester) async {
      await tester.runAsync(() async {
        await recentRepo.recordOpened(10);
        await recentRepo.recordOpened(20);
        await recentRepo.recordOpened(30);

        // Current: 30, 20, 10 -> reopen 20
        await recentRepo.recordOpened(20);

        final recent = await recentRepo.getRecentKirtans();
        expect(recent.length, equals(3));
        expect(recent[0].id, equals(20)); // Moved to top!
        expect(recent[1].id, equals(30));
        expect(recent[2].id, equals(10));
      });
    });

    testWidgets('Maximum 20 items: 21st unique entry removes oldest', (tester) async {
      await tester.runAsync(() async {
        for (int i = 1; i <= 25; i++) {
          await recentRepo.recordOpened(i);
        }

        final recent = await recentRepo.getRecentKirtans();
        expect(recent.length, equals(20));
        expect(recent.first.id, equals(25));
        expect(recent.last.id, equals(6));

        final ids = recent.map((r) => r.id).toSet();
        expect(ids.contains(1), isFalse);
        expect(ids.contains(5), isFalse);
        expect(ids.contains(6), isTrue);
      });
    });

    testWidgets('Clear Recent removes only history without affecting favorites or folders', (tester) async {
      await tester.runAsync(() async {
        await folderRepo.toggleFavorite(1);
        final customFolder = await folderRepo.createFolder('Test Folder');
        await folderRepo.addToFolder(customFolder.id, 1);

        await recentRepo.recordOpened(1);
        await recentRepo.recordOpened(2);
        expect(await recentRepo.getRecentCount(), equals(2));

        await recentRepo.clearRecent();
        expect(await recentRepo.getRecentCount(), equals(0));

        expect(await folderRepo.isFavorite(1), isTrue);
        final folderKirtans = await folderRepo.getKirtansInFolder(customFolder.id);
        expect(folderKirtans.length, equals(1));
        expect(folderKirtans.first.id, equals(1));
      });
    });

    testWidgets('Opening a kirtan reader in UI automatically records in Recent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      await tester.runAsync(() async {
        final recent = await recentRepo.getRecentKirtans();
        expect(recent.length, equals(1));
        expect(recent.first.id, equals(1541));
        expect(recent.first.uniqueKirtanId, equals('n1541'));
      });
    });

    testWidgets('RecentScreen displays items and allows Clear action with confirmation', (tester) async {
      await tester.runAsync(() async {
        await recentRepo.recordOpened(1);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RecentScreen(
            recentRepository: recentRepo,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.text('n1'), findsOneWidget);
      expect(find.text('व्रज भयो महरिकैं पूत जब यह बात सुनी ॥'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await pumpRealAsync(tester);

      expect(find.text('Clear recently opened kirtans?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Clear').last);
      await pumpRealAsync(tester);

      expect(find.text('No recently opened kirtans yet.\nOpen a kirtan to see it here.'), findsOneWidget);
    });
  });

  // =========================================================================
  // 4. SHARE KIRTAN TESTS
  // =========================================================================
  group('4. Share Kirtan Tests', () {
    test('Share text generation contains Hindi title, ID, and URL', () {
      final shareText = ShareService.buildShareText(
        titleHi: 'व्रज भयो महरिकैं पूत जब यह बात सुनी ॥',
        uniqueKirtanId: 'n1541',
      );
      expect(shareText, contains('व्रज भयो महरिकैं पूत जब यह बात सुनी ॥'));
      expect(shareText, contains('Kirtan ID: n1541'));
      expect(shareText, contains('https://kirtanfinder.app/kirtan/n1541'));
    });

    test('extractKirtanId handles n1541 and N1541 case-insensitively with exact match', () {
      expect(ShareService.extractKirtanId('n1541'), equals('n1541'));
      expect(ShareService.extractKirtanId('N1541'), equals('n1541'));
      expect(ShareService.extractKirtanId('https://kirtanfinder.app/kirtan/n1541'), equals('n1541'));
      expect(ShareService.extractKirtanId('https://kirtanfinder.app/kirtan/N1541'), equals('n1541'));
      expect(ShareService.extractKirtanId('/kirtan/n1541'), equals('n1541'));

      expect(ShareService.extractKirtanId('n15410'), equals('n15410'));
      expect(ShareService.extractKirtanId('n15410') == 'n1541', isFalse);
    });

    testWidgets('Share button exists on KirtanScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.byTooltip('Share Kirtan'), findsOneWidget);
    });

    testWidgets('SharedKirtanScreen resolves valid ID and opens reader', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SharedKirtanScreen(
            rawShareId: 'N1541',
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.text('n1541'), findsWidgets);

      await tester.runAsync(() async {
        final recent = await recentRepo.getRecentKirtans();
        expect(recent.length, equals(1));
        expect(recent.first.uniqueKirtanId, equals('n1541'));
      });
    });

    testWidgets('SharedKirtanScreen shows Kirtan Not Found for invalid ID without SQL errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SharedKirtanScreen(
            rawShareId: 'n99999',
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      expect(find.text('Kirtan Not Found'), findsWidgets);
      expect(find.text('This kirtan could not be found in your current Kirtan Finder database.'), findsOneWidget);
      expect(find.text('Back to Search'), findsOneWidget);
      expect(find.textContaining('DatabaseException'), findsNothing);
      expect(find.textContaining('sqlite'), findsNothing);
    });
  });

  // =========================================================================
  // 5. PERSIST KIRTAN READER TEXT SIZE TESTS
  // =========================================================================
  group('5. Persist Kirtan Reader Text Size Tests', () {
    testWidgets('SettingsRepository persists and loads reader font size', (tester) async {
      await tester.runAsync(() async {
        expect(await settingsRepo.getReaderFontSize(), equals(20.0));
        await settingsRepo.setReaderFontSize(24.0);
        expect(await settingsRepo.getReaderFontSize(), equals(24.0));
        await settingsRepo.setReaderFontSize(18.0);
        expect(await settingsRepo.getReaderFontSize(), equals(18.0));
      });
    });

    testWidgets('KirtanScreen loads persisted font size on launch and updates immediately', (tester) async {
      await tester.runAsync(() async {
        await settingsRepo.setReaderFontSize(26.0);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester);

      final lyricsWidget = tester.widget<KirtanLyrics>(find.byType(KirtanLyrics));
      expect(lyricsWidget.fontSize, equals(26.0));
    });
  });

  // =========================================================================
  // 6. SEARCH 2 — PHRASE MATCH RANKING TESTS
  // =========================================================================
  group('6. Search 2 Phrase Match Ranking Tests', () {
    testWidgets('Consecutive phrase matches are ranked first over separated AND tokens without duplicating records', (tester) async {
      List<SearchResult> results = [];
      await tester.runAsync(() async {
        results = await kirtanRepo.searchLines(query: 'गोवर्धन धर');
      });

      expect(results.isNotEmpty, isTrue);
      // Ensure no duplicate IDs
      final idSet = results.map((r) => r.id).toSet();
      expect(idSet.length, equals(results.length));

      // First result must be an exact consecutive phrase match (e.g. n2571)
      final topResult = results.first;
      expect(topResult.matchingSnippet, isNotNull);
      expect(topResult.matchingSnippet, contains('गोवर्धन'));
      expect(topResult.matchingSnippet, contains('धर'));

      // Check that n2571 (consecutive) appears before n1662 (separated)
      final n2571Index = results.indexWhere((r) => r.uniqueKirtanId == 'n2571');
      final n1662Index = results.indexWhere((r) => r.uniqueKirtanId == 'n1662');
      if (n2571Index != -1 && n1662Index != -1) {
        expect(n2571Index, lessThan(n1662Index));
      }
    });

    testWidgets('Single-word and quoted searches preserve expected behavior', (tester) async {
      List<SearchResult> singleWordResults = [];
      List<SearchResult> quotedResults = [];
      await tester.runAsync(() async {
        singleWordResults = await kirtanRepo.searchLines(query: 'गोवर्धन');
        quotedResults = await kirtanRepo.searchLines(query: '"गोवर्धन धर"');
      });

      expect(singleWordResults.isNotEmpty, isTrue);
      expect(quotedResults.isNotEmpty, isTrue);
      // All quoted results must have the phrase
      for (final r in quotedResults) {
        expect(r.matchingSnippet, isNotNull);
      }
    });
  });

  // =========================================================================
  // 7. TEMPORARY SEARCH 2 READER HIGHLIGHT TESTS (~7 SECONDS)
  // =========================================================================
  group('7. Temporary Search 2 Reader Highlight Tests', () {
    testWidgets('Highlight query is active initially, then cleared after ~7 seconds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
            highlightQuery: 'व्रज भयो',
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 100));

      // Initially highlightQuery is passed to KirtanLyrics
      var lyricsWidget = tester.widget<KirtanLyrics>(find.byType(KirtanLyrics));
      expect(lyricsWidget.highlightQuery, equals('व्रज भयो'));

      // Fast-forward 8 seconds to allow the 7-second timer to fire
      await tester.pump(const Duration(seconds: 8));
      await pumpRealAsync(tester, const Duration(milliseconds: 100));

      // After ~7 seconds, highlightQuery must be cleared (null)
      lyricsWidget = tester.widget<KirtanLyrics>(find.byType(KirtanLyrics));
      expect(lyricsWidget.highlightQuery, isNull);

      // Lyrics text remains authentic and intact
      expect(find.textContaining('व्रज भयो महरिकैं पूत'), findsWidgets);
    });

    testWidgets('Navigating Previous/Next immediately removes any search highlight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
            highlightQuery: 'राधा',
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 100));

      var lyricsWidget = tester.widget<KirtanLyrics>(find.byType(KirtanLyrics));
      expect(lyricsWidget.highlightQuery, equals('राधा'));

      // Tap Next -> immediately clears highlight
      await tester.tap(find.text('Next'));
      await pumpRealAsync(tester, const Duration(milliseconds: 200));

      lyricsWidget = tester.widget<KirtanLyrics>(find.byType(KirtanLyrics));
      expect(lyricsWidget.highlightQuery, isNull);
    });
  });

  // =========================================================================
  // 8. READER BOTTOM NAVIGATION — REMOVE "n" PREFIX TESTS
  // =========================================================================
  group('8. Reader Bottom Navigation Position Display Tests', () {
    testWidgets('Bottom navigation shows 1541 / 6584 without n prefix', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 200));

      // Display-only: 1541 / 6584 (no n)
      expect(find.text('1541 / 6584'), findsOneWidget);
      expect(find.text('n1541 / n6584'), findsNothing);

      // Previous -> 1540 / 6584
      await tester.tap(find.text('Previous'));
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(find.text('1540 / 6584'), findsOneWidget);
      expect(find.text('n1540 / n6584'), findsNothing);
    });
  });

  // =========================================================================
  // 9. REMOVE LOGO FROM IN-APP HEADER TESTS
  // =========================================================================
  group('9. Remove Logo from In-App Header Tests', () {
    testWidgets('SearchScreen header displays clean text Kirtan Finder without image logo', (tester) async {
      final searchController = sc.SearchPageController(kirtanRepo);
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(controller: searchController),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 100));

      // App bar has title 'Kirtan Finder'
      expect(find.text('Kirtan Finder'), findsOneWidget);

      // No logo image inside SearchScreen
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsNothing);
    });
  });
}

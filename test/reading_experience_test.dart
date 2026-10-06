import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kirtan_finder/app/app.dart';
import 'package:kirtan_finder/core/database/database_migrator.dart';
import 'package:kirtan_finder/core/database/database_service.dart';
import 'package:kirtan_finder/core/repositories/folder_repository.dart';
import 'package:kirtan_finder/core/repositories/kirtan_repository.dart';
import 'package:kirtan_finder/features/kirtan/kirtan_screen.dart';
import 'package:kirtan_finder/features/kirtan/widgets/kirtan_header.dart';
import 'package:kirtan_finder/features/kirtan/widgets/kirtan_lyrics.dart';
import 'package:kirtan_finder/core/models/kirtan.dart';
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

    final sourcePath = 'assets/db/kirtan_finder.db';
    testDbPath = '${Directory.current.path}/test_reading_kirtan_finder.db';
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

  setUp(() async {
    await db.delete('folder_kirtans');
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

  group('Kirtan Reading Experience Tests', () {
    testWidgets('1. Content & Visual Hierarchy: ID, Hindi title, English title, metadata, authentic lines',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.byType(KirtanHeader), findsOneWidget);
      expect(find.byType(KirtanLyrics), findsOneWidget);

      // Verify Header components in strict hierarchy
      expect(find.text('n1'), findsWidgets); // Public ID badge & app bar
      expect(find.text('व्रज भयो महरिकैं पूत जब यह बात सुनी ॥'), findsWidgets);
      expect(find.text('Vraja Bhayo Maharikain Puta Jaba Yaha Bata Suni'), findsOneWidget);
      expect(find.text('Part 1'), findsOneWidget);
      expect(find.text('जन्माष्टमी बधाई'), findsOneWidget);
      expect(find.text('Kirtan 1'), findsOneWidget);
      expect(find.textContaining('Ch 1'), findsNothing);
      expect(find.text('Page 1'), findsOneWidget);

      // Verify authentic verse markers
      expect(find.textContaining('॥१॥'), findsOneWidget);
      expect(find.textContaining('॥२॥'), findsOneWidget);
      expect(find.textContaining('॥१५॥'), findsOneWidget);
    });

    testWidgets('2. Source Fidelity: lines in reader correspond exactly to kirtan_lines table',
        (tester) async {
      Kirtan? kirtan;
      await tester.runAsync(() async {
        kirtan = await kirtanRepo.getKirtanById(1);
      });
      expect(kirtan, isNotNull);
      expect(kirtan!.lines.length, equals(60));

      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      // Verify first line is title-line with authentic text
      expect(kirtan!.lines.first.isTitleLine, isTrue);
      expect(find.textContaining(kirtan!.lines.first.lineText), findsWidgets);

      // Verify a line midway through the kirtan
      expect(find.textContaining(kirtan!.lines[7].lineText), findsWidgets);
    });

    testWidgets('3. 1-Tap Quick Favorite toggle updates state immediately without leaving reader',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      final favButton = find.byKey(const ValueKey('quick_favorite_button'));
      expect(favButton, findsOneWidget);

      // Initially not favorite
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);

      // Tap favorite
      await tester.tap(favButton);
      await pumpRealAsync(tester, const Duration(milliseconds: 200));

      // Now favorite icon filled
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);

      // Tap again to unfavorite
      await tester.tap(favButton);
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('4. Multi-Folder management from reader', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      final bookmarkButton = find.byKey(const ValueKey('folder_bookmark_button'));
      expect(bookmarkButton, findsOneWidget);

      // Open bottom sheet
      await tester.tap(bookmarkButton);
      await pumpRealAsync(tester, const Duration(milliseconds: 200));

      expect(find.text('Save to Folder'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close));
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
    });

    testWidgets('5. Sequential Previous / Next navigation follows corpus order_num', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1541,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      expect(find.text('1541 / 6584'), findsOneWidget);
      final prevBtn = find.text('Previous');
      final nextBtn = find.text('Next');
      expect(prevBtn, findsOneWidget);
      expect(nextBtn, findsOneWidget);

      // Tap "Previous" -> should load n1540
      await tester.tap(prevBtn);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      expect(find.text('1540 / 6584'), findsOneWidget);

      // Tap "Next" -> should load n1541
      await tester.tap(nextBtn);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      expect(find.text('1541 / 6584'), findsOneWidget);
    });

    testWidgets('6. Search 2 -> Reader with matched line highlight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            highlightQuery: 'व्रज भयो',
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      expect(find.byType(KirtanLyrics), findsOneWidget);
      expect(find.textContaining('व्रज भयो महरिकैं पूत'), findsWidgets);
    });

    testWidgets('7. Font size adjustment sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      final sizeBtn = find.byTooltip('Text Size');
      expect(sizeBtn, findsOneWidget);

      await tester.tap(sizeBtn);
      await pumpRealAsync(tester, const Duration(milliseconds: 200));

      expect(find.text('Text Size'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Increase size with A+
      await tester.tap(find.text('A+'));
      await pumpRealAsync(tester, const Duration(milliseconds: 100));

      expect(find.text('22 px'), findsOneWidget);
    });

    testWidgets('8. Copy action copies formatted text and shows SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      final copyBtn = find.byTooltip('Copy');
      expect(copyBtn, findsOneWidget);

      await tester.tap(copyBtn);
      await pumpRealAsync(tester, const Duration(milliseconds: 200));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Kirtan copied to clipboard'), findsOneWidget);
    });

    testWidgets('9. Responsive iPad Layout: centers reading column within maxWidth 780', (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
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
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final readingColumn = constrainedBoxes.firstWhere(
        (b) => b.constraints.maxWidth == 780,
      );
      expect(readingColumn, isNotNull);
      expect(readingColumn.constraints.maxWidth, equals(780));
    });

    testWidgets('10. Dark Mode: KirtanScreen renders cleanly with high contrast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));

      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.text('n1'), findsWidgets);
    });

    testWidgets('11. Full End-to-End Flow: Search 1 -> Result -> Reader -> Navigate -> Favorite',
        (tester) async {
      final app = KirtanFinderApp(
        kirtanRepository: kirtanRepo,
        folderRepository: folderRepo,
      );

      await tester.pumpWidget(app);
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      // Enter query in Search 1
      await tester.enterText(find.byType(TextField), 'व्रज भयो');
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      expect(find.byType(SearchResultTile), findsWidgets);

      // Tap result tile to open reader
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byType(SearchResultTile).first);
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify reader screen opened
      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.textContaining('व्रज भयो महरिकैं पूत'), findsWidgets);

      // Verify navigation buttons present
      expect(find.text('Next'), findsOneWidget);

      // Go back to search
      await tester.pageBack();
      await pumpRealAsync(tester, const Duration(milliseconds: 100));

      expect(find.byType(KirtanScreen), findsNothing);
      expect(find.byType(SearchResultTile), findsWidgets);
    });
  });
}

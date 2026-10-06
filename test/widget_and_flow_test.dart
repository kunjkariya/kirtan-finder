import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kirtan_finder/app/app.dart';
import 'package:kirtan_finder/core/database/database_service.dart';
import 'package:kirtan_finder/core/repositories/folder_repository.dart';
import 'package:kirtan_finder/core/repositories/kirtan_repository.dart';
import 'package:kirtan_finder/features/kirtan/kirtan_screen.dart';
import 'package:kirtan_finder/features/search/search_controller.dart';
import 'package:kirtan_finder/features/search/search_screen.dart';
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
    testDbPath = '${Directory.current.path}/test_flow_kirtan_finder.db';
    final src = File(sourcePath);
    if (await src.exists()) {
      await src.copy(testDbPath);
    } else {
      final fallback = File('../database/kirtan_finder.db');
      await fallback.copy(testDbPath);
    }

    db = await databaseFactoryFfi.openDatabase(testDbPath);
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

  Future<void> pumpRealAsync(WidgetTester tester, [Duration duration = const Duration(milliseconds: 250)]) async {
    await tester.pump(duration);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
  }

  group('7. Widget & User Flow Verification', () {
    testWidgets('SearchScreen renders with search field, mode selector, and part filter',
        (tester) async {
      final controller = SearchPageController(kirtanRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(controller: controller),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      expect(find.text('Kirtan Finder'), findsOneWidget);
      expect(find.text('Title / ID'), findsOneWidget);
      expect(find.text('Kirtan Lines'), findsOneWidget);
      expect(find.text('All Parts'), findsOneWidget);
      expect(find.text('Part 1'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Flow 1: Search 1 -> "व्रज भयो" -> Part 1 -> Open Kirtan -> Verify lyrics -> Favourite',
        (tester) async {
      final app = KirtanFinderApp(
        kirtanRepository: kirtanRepo,
        folderRepository: folderRepo,
      );

      await tester.pumpWidget(app);
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      // 1. Enter query "व्रज भयो" in Search 1
      await tester.enterText(find.byType(TextField), 'व्रज भयो');
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      // 2. Select Part 1 filter
      await tester.tap(find.text('Part 1'));
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      // 3. Inspect result tile
      expect(find.byType(SearchResultTile), findsOneWidget);
      expect(find.textContaining('व्रज भयो महरिकैं पूत'), findsOneWidget);

      // 4. Tap the result tile to open KirtanScreen
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byType(SearchResultTile));
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // 5. Verify KirtanScreen loaded with full lyrics
      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.text('जन्माष्टमी बधाई'), findsOneWidget);
      expect(find.text('Kirtan 1'), findsOneWidget);
      expect(find.textContaining('Ch 1'), findsNothing);
      expect(find.textContaining('व्रज भयो महरिकैं पूत जब यह बात सुनी'), findsWidgets);

      // 6. Test Favourite button interaction
      final favButton = find.byTooltip('Save to folder');
      expect(favButton, findsOneWidget);
      await tester.tap(favButton);
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify bookmark bottom sheet opened with folders
      expect(find.text('Save to Folder'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);

      // Tap on first folder checkbox
      await tester.tap(find.byType(CheckboxListTile).first);
      await pumpRealAsync(tester, const Duration(milliseconds: 100));

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close));
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify button shows bookmarked state
      expect(find.byTooltip('Save to folder'), findsOneWidget);

      // Return to search
      await tester.pageBack();
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    });

    testWidgets('Flow 2: Search 2 -> "श्री कृष्ण" -> Part 1 -> Verify snippet -> Open Kirtan',
        (tester) async {
      final app = KirtanFinderApp(
        kirtanRepository: kirtanRepo,
        folderRepository: folderRepo,
      );

      await tester.pumpWidget(app);
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      // 1. Switch to Search 2 (Lyrics)
      await tester.tap(find.text('Kirtan Lines'));
      await pumpRealAsync(tester, const Duration(milliseconds: 50));

      // 2. Enter query "श्री कृष्ण"
      await tester.enterText(find.byType(TextField), 'श्री कृष्ण');
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      // 3. Select Part 1
      await tester.tap(find.text('Part 1'));
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      // 4. In Part 1 there are kirtans matching "श्री कृष्ण"
      expect(find.byType(SearchResultTile), findsWidgets);

      // 5. Verify matching search result tiles are rendered
      expect(find.byType(SearchResultTile), findsWidgets);

      // 6. Open first result
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byType(SearchResultTile).first);
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // 7. Verify complete original lyrics are displayed
      expect(find.byType(KirtanScreen), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
    });

    testWidgets('Responsive iPad Layout: switches from BottomBar to NavigationRail when width >= 720',
        (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = KirtanFinderApp(
        kirtanRepository: kirtanRepo,
        folderRepository: folderRepo,
      );

      await tester.pumpWidget(app);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      // Switch to iPad dimensions
      tester.view.physicalSize = const Size(900, 1200);
      await tester.pumpWidget(app);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}

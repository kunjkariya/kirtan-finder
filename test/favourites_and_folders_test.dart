import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kirtan_finder/app/routes.dart';
import 'package:kirtan_finder/core/models/folder.dart';
import 'package:kirtan_finder/core/database/database_migrator.dart';
import 'package:kirtan_finder/core/database/database_service.dart';
import 'package:kirtan_finder/core/repositories/folder_repository.dart';
import 'package:kirtan_finder/core/repositories/kirtan_repository.dart';
import 'package:kirtan_finder/features/favourites/favourites_screen.dart';
import 'package:kirtan_finder/features/favourites/folder_screen.dart';
import 'package:kirtan_finder/features/kirtan/kirtan_screen.dart';
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
    testDbPath = '${Directory.current.path}/test_favs_kirtan_finder.db';
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
    // Clean user tables between tests
    await db.delete('folder_kirtans');
    await db.delete('folders', where: 'id != 1');
  });

  Future<void> pumpRealAsync(WidgetTester tester, [Duration duration = const Duration(milliseconds: 250)]) async {
    await tester.pump(duration);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
  }

  // ===========================================================================
  // 1. Favorites Unit Tests
  // ===========================================================================
  group('1. Favorites System Verification', () {
    test('Default Favorites folder (id=1) exists and is protected', () async {
      final folders = await folderRepo.getFoldersOrdered();
      expect(folders.any((f) => f.id == 1), isTrue);
      final fav = folders.firstWhere((f) => f.id == 1);
      expect(fav.sortOrder, equals(0));

      // Attempting to delete Favorites folder is silently ignored
      await folderRepo.deleteFolder(1);
      final foldersAfter = await folderRepo.getFoldersOrdered();
      expect(foldersAfter.any((f) => f.id == 1), isTrue);
    });

    test('Add kirtan to Favorites and verify membership', () async {
      final added = await folderRepo.toggleFavorite(10);
      expect(added, isTrue);

      final isFav = await folderRepo.isFavorite(10);
      expect(isFav, isTrue);

      final favKirtans = await folderRepo.getFolderKirtans(1);
      expect(favKirtans.length, equals(1));
      expect(favKirtans.first.id, equals(10));
    });

    test('Remove kirtan from Favorites and verify removal', () async {
      await folderRepo.toggleFavorite(10);
      expect(await folderRepo.isFavorite(10), isTrue);

      final removed = await folderRepo.toggleFavorite(10);
      expect(removed, isFalse);

      final isFav = await folderRepo.isFavorite(10);
      expect(isFav, isFalse);

      final favKirtans = await folderRepo.getFolderKirtans(1);
      expect(favKirtans.isEmpty, isTrue);
    });
  });

  // ===========================================================================
  // 2. Multiple Folders & Zero Duplication
  // ===========================================================================
  group('2. Multiple Folders & Reference Storage', () {
    test('Same kirtan can belong to multiple folders without text duplication', () async {
      final folderA = await folderRepo.createFolder('Morning Kirtans');
      final folderB = await folderRepo.createFolder('Evening Kirtans');

      // Add kirtan 25 to both folders and Favorites
      await folderRepo.addToFolder(folderA.id, 25);
      await folderRepo.addToFolder(folderB.id, 25);
      await folderRepo.addToFolder(FolderRepository.favoritesFolderId, 25);

      // Verify membership in all three
      expect(await folderRepo.isKirtanInFolder(folderA.id, 25), isTrue);
      expect(await folderRepo.isKirtanInFolder(folderB.id, 25), isTrue);
      expect(await folderRepo.isFavorite(25), isTrue);

      final folderIds = await folderRepo.getFoldersForKirtan(25);
      expect(folderIds.contains(folderA.id), isTrue);
      expect(folderIds.contains(folderB.id), isTrue);
      expect(folderIds.contains(FolderRepository.favoritesFolderId), isTrue);

      // Remove from Folder A
      await folderRepo.removeFromFolder(folderA.id, 25);

      // Verify removed from A, but remains in B and Favorites
      expect(await folderRepo.isKirtanInFolder(folderA.id, 25), isFalse);
      expect(await folderRepo.isKirtanInFolder(folderB.id, 25), isTrue);
      expect(await folderRepo.isFavorite(25), isTrue);

      // Verify that total corpus count remains exactly 6,584
      final totalKirtans = await kirtanRepo.getKirtanCount();
      expect(totalKirtans, equals(6584));
    });
  });

  // ===========================================================================
  // 3. Folder Ordering & Persistence
  // ===========================================================================
  group('3. Persistent Folder Ordering', () {
    test('Create A, B, C, D -> Reorder to C, A, D, B -> Verify database order and reload', () async {
      final fA = await folderRepo.createFolder('Folder A');
      final fB = await folderRepo.createFolder('Folder B');
      final fC = await folderRepo.createFolder('Folder C');
      final fD = await folderRepo.createFolder('Folder D');

      // Reorder to C, A, D, B (keeping Favorites at 0)
      final newOrder = [FolderRepository.favoritesFolderId, fC.id, fA.id, fD.id, fB.id];
      await folderRepo.updateFolderOrder(newOrder);

      // 1. Verify directly in SQLite table
      final rows = await db.query('folders', orderBy: 'sort_order ASC');
      final rowIds = rows.map((r) => r['id'] as int).toList();
      expect(rowIds, equals(newOrder));

      // 2. Reload via a fresh FolderRepository instance
      final freshRepo = FolderRepository(dbService);
      final loadedFolders = await freshRepo.getFoldersOrdered();
      final loadedIds = loadedFolders.map((f) => f.id).toList();
      expect(loadedIds, equals(newOrder));
      expect(loadedFolders[1].name, equals('Folder C'));
      expect(loadedFolders[2].name, equals('Folder A'));
      expect(loadedFolders[3].name, equals('Folder D'));
      expect(loadedFolders[4].name, equals('Folder B'));
    });
  });

  // ===========================================================================
  // 4. Kirtan Ordering Inside Folder & Persistence
  // ===========================================================================
  group('4. Persistent Kirtan Ordering Inside Folder', () {
    test('Folder with K1, K2, K3, K4 -> Reorder to K3, K1, K4, K2 -> Verify DB and reload', () async {
      final folder = await folderRepo.createFolder('Custom Recital');
      const kirtanIds = [1, 2, 3, 4];
      for (final id in kirtanIds) {
        await folderRepo.addToFolder(folder.id, id);
      }

      // Initial order should be 1, 2, 3, 4
      final initial = await folderRepo.getFolderKirtans(folder.id);
      expect(initial.map((k) => k.id).toList(), equals([1, 2, 3, 4]));

      // Reorder to 3, 1, 4, 2
      const targetOrder = [3, 1, 4, 2];
      await folderRepo.updateKirtanOrder(folder.id, targetOrder);

      // 1. Verify directly in SQLite folder_kirtans table
      final rows = await db.query(
        'folder_kirtans',
        where: 'folder_id = ?',
        whereArgs: [folder.id],
        orderBy: 'position ASC',
      );
      final positions = rows.map((r) => r['kirtan_id'] as int).toList();
      expect(positions, equals(targetOrder));

      // 2. Reload via repository
      final freshRepo = FolderRepository(dbService);
      final reloaded = await freshRepo.getFolderKirtans(folder.id);
      expect(reloaded.map((k) => k.id).toList(), equals(targetOrder));
    });
  });

  // ===========================================================================
  // 5. Database Close & Restart Persistence
  // ===========================================================================
  group('5. Restart Persistence', () {
    test('Folder and kirtan order survive complete database reconnection', () async {
      final restartPath = '${Directory.current.path}/test_restart_kirtan_finder.db';
      final src = File(testDbPath);
      await src.copy(restartPath);

      final rDb1 = await databaseFactoryFfi.openDatabase(restartPath);
      final rRepo1 = FolderRepository(DatabaseService.withDatabase(rDb1));

      final folder = await rRepo1.createFolder('Restart Test Folder');
      await rRepo1.addToFolder(folder.id, 101);
      await rRepo1.addToFolder(folder.id, 102);
      await rRepo1.addToFolder(folder.id, 103);
      await rRepo1.updateKirtanOrder(folder.id, [103, 101, 102]);

      // Close rDb1
      await rDb1.close();

      // Re-open from disk
      final rDb2 = await databaseFactoryFfi.openDatabase(restartPath);
      final rRepo2 = FolderRepository(DatabaseService.withDatabase(rDb2));

      // Verify folder still exists
      final folders = await rRepo2.getFoldersOrdered();
      expect(folders.any((f) => f.id == folder.id), isTrue);

      // Verify kirtan custom order is preserved
      final kirtans = await rRepo2.getFolderKirtans(folder.id);
      expect(kirtans.map((k) => k.id).toList(), equals([103, 101, 102]));

      await rDb2.close();
      final rFile = File(restartPath);
      if (await rFile.exists()) {
        await rFile.delete();
      }
    });
  });

  // ===========================================================================
  // 6. Custom Folder Deletion & Cascade Isolation
  // ===========================================================================
  group('6. Folder Deletion Verification', () {
    test('Deleting custom folder removes references but never kirtans or other folders', () async {
      final f1 = await folderRepo.createFolder('Folder To Delete');
      final f2 = await folderRepo.createFolder('Folder To Keep');

      await folderRepo.addToFolder(f1.id, 50);
      await folderRepo.addToFolder(f2.id, 50);

      // Delete f1
      await folderRepo.deleteFolder(f1.id);

      // 1. f1 is gone
      final folders = await folderRepo.getFoldersOrdered();
      expect(folders.any((f) => f.id == f1.id), isFalse);

      // 2. f2 still exists with its kirtan
      expect(folders.any((f) => f.id == f2.id), isTrue);
      final f2Kirtans = await folderRepo.getFolderKirtans(f2.id);
      expect(f2Kirtans.length, equals(1));
      expect(f2Kirtans.first.id, equals(50));

      // 3. Kirtan 50 still exists in main database
      final kirtan = await kirtanRepo.getKirtanById(50);
      expect(kirtan, isNotNull);
      expect(kirtan!.id, equals(50));
    });
  });

  // ===========================================================================
  // 7. Complete UI Flow Tests
  // ===========================================================================
  group('7. UI Flow Verification', () {
    testWidgets('Flow 1: Quick 1-tap Favorite button toggle on KirtanScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      final quickFav = find.byKey(const ValueKey('quick_favorite_button'));
      expect(quickFav, findsOneWidget);

      // Tap to favorite
      await tester.tap(quickFav);
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify marked as favorite in repo
      bool? isFav;
      await tester.runAsync(() async {
        isFav = await folderRepo.isFavorite(1);
      });
      expect(isFav, isTrue);

      // Tap again to unfavorite
      await tester.tap(quickFav);
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify removed from favorite in repo
      await tester.runAsync(() async {
        isFav = await folderRepo.isFavorite(1);
      });
      expect(isFav, isFalse);
    });

    testWidgets('Flow 2: Create folder in FavouritesScreen -> open FolderScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FavouritesScreen(folderRepository: folderRepo),
          routes: {
            AppRoutes.folderDetail: (ctx) {
              final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
              return FolderScreen(
                folderId: args['folderId'] as int,
                folderName: args['folderName'] as String,
                folderRepository: folderRepo,
              );
            },
          },
        ),
      );
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Tap FAB to create new folder
      await tester.tap(find.byType(FloatingActionButton));
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Enter name "Morning"
      await tester.enterText(find.byType(TextField), 'Morning');
      await pumpRealAsync(tester, const Duration(milliseconds: 50));
      await tester.tap(find.text('Create'));
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify "Morning" is rendered in ListTile
      expect(find.widgetWithText(ListTile, 'Morning'), findsOneWidget);

      // Tap on Morning folder
      await tester.tap(find.widgetWithText(ListTile, 'Morning'));
      for (int i = 0; i < 6; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify FolderScreen opened with empty state
      expect(find.byType(FolderScreen), findsOneWidget);
      expect(find.text('This folder is empty'), findsOneWidget);
    });

    testWidgets('Flow 3: Multiple folders membership verification in UI', (tester) async {
      late Folder fMorning;
      late Folder fJanm;
      await tester.runAsync(() async {
        fMorning = await folderRepo.createFolder('Morning');
        fJanm = await folderRepo.createFolder('Janmashtami');
      });

      await tester.pumpWidget(
        MaterialApp(
          home: KirtanScreen(
            kirtanId: 1,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Open multi-folder bottom sheet
      final folderButton = find.byKey(const ValueKey('folder_bookmark_button'));
      expect(folderButton, findsOneWidget);
      await tester.tap(folderButton);
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Check all three folders: Favorites, Morning, Janmashtami
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Janmashtami'), findsOneWidget);

      // Add to Favorites
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Favorites'));
      for (int i = 0; i < 3; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 80));
      }

      // Add to Morning
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Morning'));
      for (int i = 0; i < 3; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 80));
      }

      // Add to Janmashtami
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Janmashtami'));
      for (int i = 0; i < 3; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 80));
      }

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close));
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify kirtan 1 belongs to all three folders in repository
      bool? inFav, inMorn, inJanm;
      await tester.runAsync(() async {
        inFav = await folderRepo.isFavorite(1);
        inMorn = await folderRepo.isKirtanInFolder(fMorning.id, 1);
        inJanm = await folderRepo.isKirtanInFolder(fJanm.id, 1);
      });
      expect(inFav, isTrue);
      expect(inMorn, isTrue);
      expect(inJanm, isTrue);
    });

    testWidgets('Flow 4: Reorder folders persists across navigation', (tester) async {
      await tester.runAsync(() async {
        final fA = await folderRepo.createFolder('Morning');
        final fB = await folderRepo.createFolder('Janmashtami');
        final fC = await folderRepo.createFolder('Dhrupad');

        // Reorder folders: Dhrupad, Morning, Janmashtami
        await folderRepo.updateFolderOrder([
          FolderRepository.favoritesFolderId,
          fC.id,
          fA.id,
          fB.id,
        ]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FavouritesScreen(folderRepository: folderRepo),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify custom display order: Favorites -> Dhrupad -> Morning -> Janmashtami
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles.length, equals(4));
      expect((tiles[0].title as Row).children.any((w) => w is Flexible && (w.child as Text).data == 'Favorites'), isTrue);
      expect((tiles[1].title as Row).children.any((w) => w is Flexible && (w.child as Text).data == 'Dhrupad'), isTrue);
      expect((tiles[2].title as Row).children.any((w) => w is Flexible && (w.child as Text).data == 'Morning'), isTrue);
      expect((tiles[3].title as Row).children.any((w) => w is Flexible && (w.child as Text).data == 'Janmashtami'), isTrue);
    });

    testWidgets('Flow 5: Reorder kirtans inside folder persists across reloads', (tester) async {
      late Folder folder;
      await tester.runAsync(() async {
        folder = await folderRepo.createFolder('Kirtan Sequence');
        await folderRepo.addToFolder(folder.id, 1);
        await folderRepo.addToFolder(folder.id, 2);
        await folderRepo.addToFolder(folder.id, 3);

        // Reorder kirtans to 3, 1, 2
        await folderRepo.updateKirtanOrder(folder.id, [3, 1, 2]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FolderScreen(
            folderId: folder.id,
            folderName: folder.name,
            folderRepository: folderRepo,
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }

      // Verify that SearchResultTile items are displayed in order 3, 1, 2
      final searchTiles = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).toList();
      expect(searchTiles.length, equals(3));
      expect(searchTiles[0].result.id, equals(3));
      expect(searchTiles[1].result.id, equals(1));
      expect(searchTiles[2].result.id, equals(2));
    });
  });
}

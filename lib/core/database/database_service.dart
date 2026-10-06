import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database_migrator.dart';

/// DatabaseService handles copying the bundled pre-indexed SQLite database
/// from Flutter assets to the app's writable document directory on first launch,
/// and providing database connections for both production and tests.
class DatabaseService {
  static const String databaseFileName = 'kirtan_finder.db';
  static const String assetDbPath = 'assets/db/$databaseFileName';

  Database? _db;

  DatabaseService([this._db]);

  /// Creates a service wrapping an already opened database (e.g. in tests).
  DatabaseService.withDatabase(Database database) : _db = database;

  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('Database has not been initialized. Call init() first.');
    }
    return _db!;
  }

  bool get isInitialized => _db != null && _db!.isOpen;

  /// Initializes the database.
  /// Copies from bundled assets if not already copied to the app documents directory.
  Future<void> init({String? customPath}) async {
    if (_db != null && _db!.isOpen) return;

    final String dbPath = customPath ?? await _resolveDatabasePath();

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      debugPrint('Database not found at $dbPath. Copying from asset $assetDbPath...');
      await dbFile.parent.create(recursive: true);

      // Copy from bundled asset
      final ByteData data = await rootBundle.load(assetDbPath);
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await dbFile.writeAsBytes(bytes, flush: true);
      debugPrint('Database copied successfully (${bytes.length} bytes).');
    }

    _db = await openDatabase(
      dbPath,
      readOnly: false,
      singleInstance: true,
      onOpen: (db) async {
        // Enable foreign keys and run safe user data migration
        await db.execute('PRAGMA foreign_keys = ON;');
        await DatabaseMigrator.migrate(db);
      },
    );
    debugPrint('Database successfully opened at $dbPath');
  }

  /// Ensures database schema is up-to-date with current migrations.
  Future<void> ensureMigrated() async {
    if (_db != null && _db!.isOpen) {
      await DatabaseMigrator.migrate(_db!);
    }
  }

  Future<String> _resolveDatabasePath() async {
    if (kIsWeb) {
      return databaseFileName;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final targetPath = p.join(docDir.path, databaseFileName);

    // On Android, if an existing database exists in legacy getDatabasesPath() (e.g. from prior install),
    // migrate it across so user favorites and folders are seamlessly preserved:
    if (Platform.isAndroid) {
      try {
        final legacyDir = await getDatabasesPath();
        final legacyFile = File(p.join(legacyDir, databaseFileName));
        final targetFile = File(targetPath);
        if (await legacyFile.exists() && !await targetFile.exists()) {
          debugPrint('Migrating existing user database from $legacyFile to $targetFile');
          await targetFile.parent.create(recursive: true);
          await legacyFile.copy(targetPath);
        }
      } catch (e) {
        debugPrint('Legacy DB check skipped: $e');
      }
    }

    return targetPath;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}

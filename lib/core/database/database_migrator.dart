import 'package:sqflite/sqflite.dart';

/// Handles safe schema migrations for user data (folders, bookmarks, custom ordering).
/// Guarantees that existing user folders and bookmarks are never lost,
/// and that kirtan text/source data remains strictly untouched.
class DatabaseMigrator {
  static const int currentVersion = 2;

  /// Migrates the database to [currentVersion] if needed.
  static Future<void> migrate(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');

    // 0. Ensure user tables exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_system INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS folder_kirtans (
        folder_id INTEGER NOT NULL,
        kirtan_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (folder_id, kirtan_id),
        FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE,
        FOREIGN KEY (kirtan_id) REFERENCES kirtans(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recent_kirtans (
        kirtan_id INTEGER PRIMARY KEY,
        opened_at INTEGER NOT NULL,
        FOREIGN KEY (kirtan_id) REFERENCES kirtans(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recent_kirtans_opened ON recent_kirtans(opened_at DESC);
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // 1. Check folders table columns
    final folderCols = await db.rawQuery('PRAGMA table_info(folders);');
    final folderColNames = folderCols.map((c) => c['name'] as String).toSet();

    if (!folderColNames.contains('sort_order')) {
      await db.execute('ALTER TABLE folders ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;');
    }
    if (!folderColNames.contains('is_system')) {
      await db.execute('ALTER TABLE folders ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0;');
    }

    // 2. Check folder_kirtans table columns
    final fkCols = await db.rawQuery('PRAGMA table_info(folder_kirtans);');
    final fkColNames = fkCols.map((c) => c['name'] as String).toSet();

    if (!fkColNames.contains('position')) {
      await db.execute('ALTER TABLE folder_kirtans ADD COLUMN position INTEGER NOT NULL DEFAULT 0;');
    }

    // 3. Ensure canonical unique_kirtan_id (n1..n6584) exists in kirtans
    final kirtanCols = await db.rawQuery('PRAGMA table_info(kirtans);');
    final kirtanColNames = kirtanCols.map((c) => c['name'] as String).toSet();

    if (!kirtanColNames.contains('unique_kirtan_id')) {
      await db.execute('ALTER TABLE kirtans ADD COLUMN unique_kirtan_id TEXT;');
      await db.execute("UPDATE kirtans SET unique_kirtan_id = 'n' || order_num;");
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_kirtans_unique_kirtan_id ON kirtans(unique_kirtan_id);');
    } else {
      // Migrate legacy uppercase/zero-padded IDs (e.g. N0001, N1541) to short lowercase IDs (n1..n6584)
      final sample = await db.rawQuery("SELECT unique_kirtan_id FROM kirtans WHERE unique_kirtan_id LIKE 'N%' LIMIT 1;");
      if (sample.isNotEmpty) {
        await db.execute("UPDATE kirtans SET unique_kirtan_id = 'n' || order_num;");
      }
    }

    // 3. Versioned migration step
    final versionRows = await db.rawQuery('PRAGMA user_version;');
    final currentDbVersion = (versionRows.first['user_version'] as int?) ?? 0;

    if (currentDbVersion < 2) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Ensure system Favorites folder exists (id = 1)
      final favRows = await db.rawQuery('SELECT id, name FROM folders WHERE id = 1;');
      if (favRows.isEmpty) {
        await db.rawInsert('''
          INSERT INTO folders (id, name, sort_order, is_system, created_at, updated_at)
          VALUES (1, 'Favorites', 0, 1, ?, ?);
        ''', [now, now]);
      } else {
        await db.execute("UPDATE folders SET is_system = 1, sort_order = 0 WHERE id = 1;");
        final name = favRows.first['name'] as String?;
        if (name == 'Daily Nityaniem') {
          await db.execute("UPDATE folders SET name = 'Favorites' WHERE id = 1;");
        }
      }

      // Assign deterministic sequential sort_order to existing folders
      final allFolders = await db.rawQuery(
        'SELECT id, is_system FROM folders ORDER BY is_system DESC, id ASC;',
      );
      for (int i = 0; i < allFolders.length; i++) {
        final fId = allFolders[i]['id'] as int;
        await db.rawUpdate('UPDATE folders SET sort_order = ? WHERE id = ?;', [i, fId]);
      }

      // Assign deterministic sequential positions to existing folder_kirtans
      final allFolderIds = await db.rawQuery('SELECT DISTINCT folder_id FROM folder_kirtans;');
      for (final row in allFolderIds) {
        final fId = row['folder_id'] as int;
        final kirtans = await db.rawQuery(
          'SELECT kirtan_id FROM folder_kirtans WHERE folder_id = ? ORDER BY added_at ASC, kirtan_id ASC;',
          [fId],
        );
        for (int pos = 0; pos < kirtans.length; pos++) {
          final kId = kirtans[pos]['kirtan_id'] as int;
          await db.rawUpdate(
            'UPDATE folder_kirtans SET position = ? WHERE folder_id = ? AND kirtan_id = ?;',
            [pos, fId, kId],
          );
        }
      }

      // Create performance indexes for custom ordering
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_folder_kirtans_pos ON folder_kirtans(folder_id, position);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_folders_sort ON folders(sort_order);',
      );

      // Set user_version to 2
      await db.execute('PRAGMA user_version = $currentVersion;');
    }
  }
}

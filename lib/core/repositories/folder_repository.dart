import 'package:sqflite/sqflite.dart';
import '../database/database_migrator.dart';
import '../database/database_service.dart';
import '../models/folder.dart';
import '../models/search_result.dart';

/// Repository for managing folders and favourite kirtan bookmarks.
/// Favourites are treated strictly as references (IDs) in `folder_kirtans`,
/// guaranteeing zero lyric or metadata text duplication.
/// Both folders and kirtans inside each folder support persistent custom ordering.
class FolderRepository {
  static const int favoritesFolderId = 1;

  final DatabaseService _dbService;
  bool _migrated = false;

  FolderRepository(this._dbService);

  Database get _db => _dbService.database;

  Future<void> _ensureReady() async {
    if (!_migrated) {
      await DatabaseMigrator.migrate(_db);
      _migrated = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Folder Operations
  // ---------------------------------------------------------------------------

  /// Retrieves all folders ordered by their custom persistent sort order.
  Future<List<Folder>> getFoldersOrdered() async {
    await _ensureReady();
    const sql = '''
      SELECT f.id, f.name, f.sort_order, f.is_system, f.created_at, f.updated_at,
             COUNT(fk.kirtan_id) AS kirtan_count
      FROM folders f
      LEFT JOIN folder_kirtans fk ON fk.folder_id = f.id
      GROUP BY f.id
      ORDER BY f.sort_order ASC, f.id ASC;
    ''';
    final rows = await _db.rawQuery(sql);
    return rows.map(Folder.fromMap).toList();
  }

  /// Alias for [getFoldersOrdered].
  Future<List<Folder>> getFolders() => getFoldersOrdered();

  /// Creates a new custom folder with a validated trimmed name and sequential sort order.
  Future<Folder> createFolder(String name) async {
    await _ensureReady();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    if (trimmed.length > 60) {
      throw ArgumentError('Folder name cannot exceed 60 characters');
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Determine the next sequential sort_order
    final res = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM folders;',
    );
    final nextOrder = (res.first['next_order'] as int?) ?? 0;

    final id = await _db.insert('folders', {
      'name': trimmed,
      'sort_order': nextOrder,
      'is_system': 0,
      'created_at': now,
      'updated_at': now,
    });

    return Folder(
      id: id,
      name: trimmed,
      sortOrder: nextOrder,
      isSystem: false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now * 1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now * 1000),
      kirtanCount: 0,
    );
  }

  /// Renames an existing folder. Protects system Favorites from corruption.
  Future<void> renameFolder(int folderId, String newName) async {
    await _ensureReady();
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    if (trimmed.length > 60) {
      throw ArgumentError('Folder name cannot exceed 60 characters');
    }

    // Check if protected system folder
    final rows = await _db.query(
      'folders',
      columns: ['is_system'],
      where: 'id = ?',
      whereArgs: [folderId],
    );
    if (rows.isNotEmpty && (rows.first['is_system'] as int? ?? 0) == 1 && folderId == favoritesFolderId) {
      // Favorites name is protected
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.update(
      'folders',
      {'name': trimmed, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  /// Deletes a custom folder and its memberships.
  /// The system Favorites folder is strictly protected and cannot be deleted.
  /// Kirtan records themselves are never deleted.
  Future<void> deleteFolder(int folderId) async {
    await _ensureReady();
    if (folderId == favoritesFolderId) return;

    final rows = await _db.query(
      'folders',
      columns: ['is_system'],
      where: 'id = ?',
      whereArgs: [folderId],
    );
    if (rows.isEmpty || (rows.first['is_system'] as int? ?? 0) == 1) {
      return;
    }

    await _db.transaction((txn) async {
      await txn.delete('folder_kirtans', where: 'folder_id = ?', whereArgs: [folderId]);
      await txn.delete('folders', where: 'id = ?', whereArgs: [folderId]);

      // Re-normalize remaining sort orders
      final remaining = await txn.query(
        'folders',
        columns: ['id'],
        orderBy: 'sort_order ASC, id ASC',
      );
      for (int i = 0; i < remaining.length; i++) {
        await txn.update(
          'folders',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [remaining[i]['id']],
        );
      }
    });
  }

  /// Reorders folders given [oldIndex] and [newIndex] (using standard ReorderableListView semantics).
  Future<void> reorderFolders(int oldIndex, int newIndex) async {
    int adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex -= 1;
    }
    final folders = await getFoldersOrdered();
    if (oldIndex < 0 || oldIndex >= folders.length || adjustedNewIndex < 0 || adjustedNewIndex >= folders.length) {
      return;
    }

    final item = folders.removeAt(oldIndex);
    folders.insert(adjustedNewIndex, item);

    await updateFolderOrder(folders.map((f) => f.id).toList());
  }

  /// Explicitly sets the order of folders by their IDs.
  Future<void> updateFolderOrder(List<int> orderedFolderIds) async {
    await _ensureReady();
    await _db.transaction((txn) async {
      for (int i = 0; i < orderedFolderIds.length; i++) {
        await txn.update(
          'folders',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [orderedFolderIds[i]],
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Kirtan Folder Membership & Ordering
  // ---------------------------------------------------------------------------

  /// Adds a kirtan reference into a folder at the next sequential position.
  /// Prevents duplicate membership.
  Future<bool> addToFolder(int folderId, int kirtanId) async {
    await _ensureReady();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Find next position
    final posRes = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next_pos FROM folder_kirtans WHERE folder_id = ?;',
      [folderId],
    );
    final nextPos = (posRes.first['next_pos'] as int?) ?? 0;

    final id = await _db.rawInsert('''
      INSERT OR IGNORE INTO folder_kirtans (folder_id, kirtan_id, position, added_at)
      VALUES (?, ?, ?, ?);
    ''', [folderId, kirtanId, nextPos, now]);

    return id > 0;
  }

  /// Alias for [addToFolder].
  Future<bool> addKirtanToFolder(int folderId, int kirtanId) => addToFolder(folderId, kirtanId);

  /// Removes a kirtan reference from a folder and re-normalizes positions.
  Future<bool> removeFromFolder(int folderId, int kirtanId) async {
    await _ensureReady();
    return await _db.transaction((txn) async {
      final count = await txn.delete(
        'folder_kirtans',
        where: 'folder_id = ? AND kirtan_id = ?',
        whereArgs: [folderId, kirtanId],
      );

      if (count > 0) {
        // Re-normalize positions
        final remaining = await txn.query(
          'folder_kirtans',
          columns: ['kirtan_id'],
          where: 'folder_id = ?',
          whereArgs: [folderId],
          orderBy: 'position ASC, added_at ASC',
        );
        for (int i = 0; i < remaining.length; i++) {
          await txn.update(
            'folder_kirtans',
            {'position': i},
            where: 'folder_id = ? AND kirtan_id = ?',
            whereArgs: [folderId, remaining[i]['kirtan_id']],
          );
        }
        return true;
      }
      return false;
    });
  }

  /// Alias for [removeFromFolder].
  Future<bool> removeKirtanFromFolder(int folderId, int kirtanId) => removeFromFolder(folderId, kirtanId);

  /// Retrieves all kirtans bookmarked inside a specific folder in their custom order.
  Future<List<SearchResult>> getFolderKirtans(int folderId) async {
    await _ensureReady();
    const sql = '''
      SELECT k.id, k.unique_kirtan_id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
             k.old_page, k.raag, k.raag_normalized, k.title_hi, k.title_en,
             k.raw_first_line, k.source_filename, k.source_anchor,
             NULL as matching_snippet, 0.0 as rank
      FROM kirtans k
      JOIN folder_kirtans fk ON fk.kirtan_id = k.id
      WHERE fk.folder_id = ?
      ORDER BY fk.position ASC, fk.added_at ASC;
    ''';
    final rows = await _db.rawQuery(sql, [folderId]);
    return rows.map(SearchResult.fromMap).toList();
  }

  /// Alias for [getFolderKirtans].
  Future<List<SearchResult>> getKirtansInFolder(int folderId) => getFolderKirtans(folderId);

  /// Reorders kirtans within a folder given [oldIndex] and [newIndex].
  Future<void> reorderKirtans(int folderId, int oldIndex, int newIndex) async {
    int adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex -= 1;
    }
    final kirtans = await getFolderKirtans(folderId);
    if (oldIndex < 0 || oldIndex >= kirtans.length || adjustedNewIndex < 0 || adjustedNewIndex >= kirtans.length) {
      return;
    }

    final item = kirtans.removeAt(oldIndex);
    kirtans.insert(adjustedNewIndex, item);

    await updateKirtanOrder(folderId, kirtans.map((k) => k.id).toList());
  }

  /// Explicitly sets the order of kirtans inside a folder by their IDs.
  Future<void> updateKirtanOrder(int folderId, List<int> orderedKirtanIds) async {
    await _ensureReady();
    await _db.transaction((txn) async {
      for (int i = 0; i < orderedKirtanIds.length; i++) {
        await txn.update(
          'folder_kirtans',
          {'position': i},
          where: 'folder_id = ? AND kirtan_id = ?',
          whereArgs: [folderId, orderedKirtanIds[i]],
        );
      }
    });
  }

  /// Checks if a kirtan is in a specific folder.
  Future<bool> isKirtanInFolder(int folderId, int kirtanId) async {
    await _ensureReady();
    final rows = await _db.rawQuery('''
      SELECT 1 FROM folder_kirtans WHERE folder_id = ? AND kirtan_id = ? LIMIT 1;
    ''', [folderId, kirtanId]);
    return rows.isNotEmpty;
  }

  /// Returns the IDs of all folders that contain the given kirtan.
  Future<List<int>> getFoldersForKirtan(int kirtanId) async {
    await _ensureReady();
    final rows = await _db.query(
      'folder_kirtans',
      columns: ['folder_id'],
      where: 'kirtan_id = ?',
      whereArgs: [kirtanId],
    );
    return rows.map((r) => r['folder_id'] as int).toList();
  }

  /// Alias for [getFoldersForKirtan].
  Future<List<int>> getFolderIdsForKirtan(int kirtanId) => getFoldersForKirtan(kirtanId);

  /// Checks if a kirtan is bookmarked in any folder.
  Future<bool> isKirtanBookmarked(int kirtanId) async {
    await _ensureReady();
    final rows = await _db.rawQuery('''
      SELECT 1 FROM folder_kirtans WHERE kirtan_id = ? LIMIT 1;
    ''', [kirtanId]);
    return rows.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Favorites Convenience Methods (Treats Folder 1 as System Favorites)
  // ---------------------------------------------------------------------------

  /// Checks if the kirtan is currently in the system Favorites folder.
  Future<bool> isFavorite(int kirtanId) async {
    return isKirtanInFolder(favoritesFolderId, kirtanId);
  }

  /// Toggles favorite status for a kirtan. Returns `true` if added, `false` if removed.
  Future<bool> toggleFavorite(int kirtanId) async {
    final inFav = await isFavorite(kirtanId);
    if (inFav) {
      await removeFromFolder(favoritesFolderId, kirtanId);
      return false;
    } else {
      await addToFolder(favoritesFolderId, kirtanId);
      return true;
    }
  }
}

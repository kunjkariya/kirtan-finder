import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';
import '../models/search_result.dart';

/// Repository managing user recently opened kirtans.
///
/// Constraints:
/// - Max 20 unique kirtans.
/// - Opening an already-recent kirtan moves it to the top.
/// - Persists across app restarts.
/// - Only references kirtan_id; never duplicates kirtan text/metadata.
class RecentRepository {
  final DatabaseService _dbService;
  static const int maxRecentLimit = 20;

  RecentRepository(this._dbService);

  Database get _db => _dbService.database;

  /// Records that a kirtan was opened in the reader.
  /// Moves the kirtan to the top of the history without creating duplicates.
  /// Prunes oldest entries to maintain at most [maxRecentLimit] items.
  Future<void> recordOpened(int kirtanId) async {
    final nowTime = DateTime.now().microsecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.rawInsert('''
        INSERT OR REPLACE INTO recent_kirtans (kirtan_id, opened_at)
        VALUES (?, ?);
      ''', [kirtanId, nowTime]);

      // Prune any items beyond the 20 most recent
      await txn.rawDelete('''
        DELETE FROM recent_kirtans
        WHERE kirtan_id NOT IN (
          SELECT kirtan_id FROM recent_kirtans
          ORDER BY opened_at DESC
          LIMIT ?
        );
      ''', [maxRecentLimit]);
    });
  }

  /// Retrieves the list of recently opened kirtans in reverse chronological order.
  Future<List<SearchResult>> getRecentKirtans() async {
    final rows = await _db.rawQuery('''
      SELECT k.id, k.unique_kirtan_id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
             k.old_page, k.raag, k.raag_normalized, k.title_hi, k.title_en,
             k.raw_first_line, k.source_filename, k.source_anchor,
             c.title_hi AS chapter_title,
             NULL as matching_snippet, 0.0 as rank
      FROM recent_kirtans r
      JOIN kirtans k ON r.kirtan_id = k.id
      JOIN chapters c ON k.chapter_id = c.id
      ORDER BY r.opened_at DESC
      LIMIT ?;
    ''', [maxRecentLimit]);

    return rows.map(SearchResult.fromMap).toList();
  }

  /// Clears only the recently opened history.
  /// Does NOT affect favorites, folders, custom ordering, or kirtan data.
  Future<void> clearRecent() async {
    await _db.execute('DELETE FROM recent_kirtans;');
  }

  /// Returns current count of recent entries.
  Future<int> getRecentCount() async {
    final res = await _db.rawQuery('SELECT COUNT(*) AS c FROM recent_kirtans;');
    return Sqflite.firstIntValue(res) ?? 0;
  }
}

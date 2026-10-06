import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';
import '../models/chapter.dart';
import '../models/kirtan.dart';
import '../models/kirtan_line.dart';
import '../models/part.dart';
import '../models/search_result.dart';

/// Repository implementing verified search semantics and content retrieval
/// from the SQLite Kirtan Sangrah database.
class KirtanRepository {
  final DatabaseService _dbService;

  KirtanRepository(this._dbService);

  DatabaseService get dbService => _dbService;
  Database get _db => _dbService.database;

  static const Map<String, String> _devToLat = {
    '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
    '५': '5', '६': '6', '७': '7', '८': '8', '९': '9',
  };

  /// Normalizes Devanagari numerals to ASCII digits.
  static String normalizeNumerals(String text) {
    var result = text;
    _devToLat.forEach((dev, lat) {
      result = result.replaceAll(dev, lat);
    });
    return result;
  }

  // ---------------------------------------------------------------------------
  // Validation / Diagnostics
  // ---------------------------------------------------------------------------

  Future<int> getKirtanCount() async {
    final res = await _db.rawQuery('SELECT COUNT(*) AS c FROM kirtans;');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> getChapterCount() async {
    final res = await _db.rawQuery('SELECT COUNT(*) AS c FROM chapters;');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> getPartCount() async {
    final res = await _db.rawQuery('SELECT COUNT(*) AS c FROM parts;');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<Part>> getParts() async {
    final rows = await _db.query('parts', orderBy: 'part_number ASC');
    return rows.map(Part.fromMap).toList();
  }

  Future<List<Chapter>> getChaptersByPart(int partNumber) async {
    final rows = await _db.query(
      'chapters',
      where: 'part_number = ?',
      whereArgs: [partNumber],
      orderBy: 'chapter_number ASC',
    );
    return rows.map(Chapter.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // SEARCH 1: Title & Number Search
  // ---------------------------------------------------------------------------

  /// Searches titles, old printed page numbers, and canonical unique IDs (e.g. n1..n6584).
  /// Precedence:
  /// 1. Public Kirtan ID pattern (e.g. n1, N1, n1541, N1541) -> exact unique Kirtan lookup
  /// 2. Bare integer (e.g. 25, २५) -> old printed page lookup
  /// 3. Everything else -> true substring search across title_hi, raw_first_line, and title_en
  Future<List<SearchResult>> searchTitle({
    required String query,
    PartFilter partFilter = PartFilter.all,
    int limit = 50,
    int offset = 0,
  }) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return [];

    final normalized = normalizeNumerals(rawQuery);

    // 1. Check for Public Kirtan ID pattern: e.g. n1, N1, n123, n1541, N1541
    final nRegex = RegExp(r'^[nN](\d+)$');
    final nMatch = nRegex.firstMatch(normalized);
    if (nMatch != null) {
      final canonicalId = 'n${nMatch.group(1)!}';

      var sql = '''
        SELECT k.id, k.unique_kirtan_id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
               k.old_page, k.raag, k.raag_normalized, k.title_hi, k.title_en,
               k.raw_first_line, k.source_filename, k.source_anchor,
               c.title_hi AS chapter_title,
               NULL as matching_snippet, 0.0 as rank
        FROM kirtans k
        JOIN chapters c ON k.chapter_id = c.id
        WHERE k.unique_kirtan_id = ?
      ''';
      final params = <dynamic>[canonicalId];
      if (partFilter.partNumber != null) {
        sql += ' AND k.part_number = ?';
        params.add(partFilter.partNumber!);
      }
      sql += ' LIMIT ? OFFSET ?;';
      params.addAll([limit, offset]);

      final rows = await _db.rawQuery(sql, params);
      return rows.map(SearchResult.fromMap).toList();
    }

    // 2. Check for Bare Integer (Old Printed Page Number, e.g. "25" or "२५")
    final intPage = int.tryParse(normalized);
    if (intPage != null && intPage > 0) {
      var sql = '''
        SELECT k.id, k.unique_kirtan_id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
               k.old_page, k.raag, k.raag_normalized, k.title_hi, k.title_en,
               k.raw_first_line, k.source_filename, k.source_anchor,
               c.title_hi AS chapter_title,
               NULL as matching_snippet, 0.0 as rank
        FROM kirtans k
        JOIN chapters c ON k.chapter_id = c.id
        WHERE k.old_page = ?
      ''';
      final params = <dynamic>[intPage];
      if (partFilter.partNumber != null) {
        sql += ' AND k.part_number = ?';
        params.add(partFilter.partNumber!);
      }
      sql += ' ORDER BY k.part_number, k.chapter_number, k.kirtan_number LIMIT ? OFFSET ?;';
      params.addAll([limit, offset]);

      final rows = await _db.rawQuery(sql, params);
      return rows.map(SearchResult.fromMap).toList();
    }

    // 3. Substring Text Search across title_hi, raw_first_line, and title_en
    var sql = '''
      SELECT k.id, k.unique_kirtan_id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
             k.old_page, k.raag, k.raag_normalized, k.title_hi, k.title_en,
             k.raw_first_line, k.source_filename, k.source_anchor,
             c.title_hi AS chapter_title,
             NULL as matching_snippet, 0.0 as rank
      FROM kirtans k
      JOIN chapters c ON k.chapter_id = c.id
      WHERE (
        INSTR(COALESCE(k.title_hi, ''), ?) > 0
        OR INSTR(COALESCE(k.raw_first_line, ''), ?) > 0
        OR INSTR(LOWER(COALESCE(k.title_en, '')), LOWER(?)) > 0
      )
    ''';
    final params = <dynamic>[rawQuery, rawQuery, rawQuery];
    if (partFilter.partNumber != null) {
      sql += ' AND k.part_number = ?';
      params.add(partFilter.partNumber!);
    }
    sql += ' ORDER BY k.part_number, k.old_page, k.chapter_number, k.kirtan_number LIMIT ? OFFSET ?;';
    params.addAll([limit, offset]);

    final rows = await _db.rawQuery(sql, params);
    return rows.map(SearchResult.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // SEARCH 2: Kirtan Lines Search Only
  // ---------------------------------------------------------------------------

  /// Searches ONLY actual lyric lines of kirtans.
  /// Generates highlighted matching snippet.
  /// Uses FTS5 table `lines_search_fts` as primary engine, and automatically
  /// falls back to resilient SQL search if FTS5 is unavailable on the runtime.
  Future<List<SearchResult>> searchLines({
    required String query,
    PartFilter partFilter = PartFilter.all,
    int limit = 50,
    int offset = 0,
  }) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return [];

    final isExplicitPhrase = rawQuery.startsWith('"') && rawQuery.endsWith('"') && rawQuery.length > 2;
    final cleaned = rawQuery.replaceAll(RegExp(r'["\x27\*\(\)\{\}\[\]\^\~]'), ' ').trim();
    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final isMultiWord = !isExplicitPhrase && tokens.length > 1;
    final consecutivePhrase = tokens.join(' ');

    try {
      final ftsQuery = _prepareLinesFtsQuery(rawQuery);
      if (ftsQuery.isEmpty) return [];

      String phraseScoreSql = '';
      final params = <dynamic>[];

      if (isMultiWord) {
        phraseScoreSql = '''
          CASE WHEN EXISTS (
            SELECT 1 FROM kirtan_lines kl
            WHERE kl.kirtan_id = k.id AND INSTR(kl.line_text, ?) > 0
          ) THEN 0 ELSE 1 END AS phrase_score,
        ''';
        params.add(consecutivePhrase);
      }
      params.add(ftsQuery);

      var sql = '''
        SELECT k.id, k.unique_kirtan_id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
               k.old_page, k.raag, k.raag_normalized, k.title_hi, k.title_en,
               k.raw_first_line, k.source_filename, k.source_anchor,
               c.title_hi AS chapter_title,
               snippet(lines_search_fts, 1, '<mark>', '</mark>', '...', 24) AS matching_snippet,
               $phraseScoreSql
               f.rank
        FROM lines_search_fts f
        JOIN kirtans k ON k.id = f.kirtan_id
        JOIN chapters c ON k.chapter_id = c.id
        WHERE lines_search_fts MATCH ?
      ''';
      if (partFilter.partNumber != null) {
        sql += ' AND k.part_number = ?';
        params.add(partFilter.partNumber!);
      }
      if (isMultiWord) {
        sql += ' ORDER BY phrase_score ASC, f.rank, k.part_number, k.chapter_number, k.kirtan_number LIMIT ? OFFSET ?;';
      } else {
        sql += ' ORDER BY f.rank, k.part_number, k.chapter_number, k.kirtan_number LIMIT ? OFFSET ?;';
      }
      params.addAll([limit, offset]);

      final rows = await _db.rawQuery(sql, params);
      return rows.map(SearchResult.fromMap).toList();
    } catch (e, stack) {
      debugPrint('FTS5 lines search note ($e)\n$stack\nFalling back to resilient direct SQL search.');
      return _fallbackSearchLines(
        rawQuery: rawQuery,
        partFilter: partFilter,
        limit: limit,
        offset: offset,
      );
    }
  }

  /// Resilient direct SQL search over `kirtan_lines` table.
  /// Preserves exact Devanagari semantics, AND behavior, phrase queries,
  /// Part filtering, and highlighted snippet generation.
  Future<List<SearchResult>> _fallbackSearchLines({
    required String rawQuery,
    required PartFilter partFilter,
    required int limit,
    required int offset,
  }) async {
    final isExplicitPhrase = rawQuery.startsWith('"') && rawQuery.endsWith('"') && rawQuery.length > 2;
    List<String> tokens;
    if (isExplicitPhrase) {
      final inner = rawQuery.substring(1, rawQuery.length - 1).trim();
      tokens = inner.isNotEmpty ? [inner] : [];
    } else {
      final cleaned = rawQuery.replaceAll(RegExp(r'["\x27\*\(\)\{\}\[\]\^\~]'), ' ').trim();
      tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    }

    if (tokens.isEmpty) return [];

    final isMultiWord = !isExplicitPhrase && tokens.length > 1;
    final consecutivePhrase = tokens.join(' ');

    final whereConditions = <String>[];
    final params = <dynamic>[];

    // Part filter
    if (partFilter.partNumber != null) {
      whereConditions.add('k.part_number = ?');
      params.add(partFilter.partNumber!);
    }

    // For phrase search: exact phrase in at least one line of the kirtan
    // For word search: each token must exist in the kirtan's lines (AND condition)
    for (final token in tokens) {
      whereConditions.add('EXISTS (SELECT 1 FROM kirtan_lines kl WHERE kl.kirtan_id = k.id AND INSTR(kl.line_text, ?) > 0)');
      params.add(token);
    }

    final whereClause = whereConditions.join(' AND ');
    final primaryToken = tokens.first;

    String phraseScoreSql = '';
    final execParams = <dynamic>[];

    if (isMultiWord) {
      phraseScoreSql = '''
        CASE WHEN EXISTS (
          SELECT 1 FROM kirtan_lines kl
          WHERE kl.kirtan_id = k.id AND INSTR(kl.line_text, ?) > 0
        ) THEN 0 ELSE 1 END AS phrase_score,
      ''';
      execParams.add(consecutivePhrase);
    }

    final lineSnippetSql = isMultiWord
        ? '''
          COALESCE(
            (SELECT kl.line_text FROM kirtan_lines kl WHERE kl.kirtan_id = k.id AND INSTR(kl.line_text, ?) > 0 LIMIT 1),
            (SELECT kl.line_text FROM kirtan_lines kl WHERE kl.kirtan_id = k.id AND INSTR(kl.line_text, ?) > 0 LIMIT 1)
          )
        '''
        : '(SELECT kl.line_text FROM kirtan_lines kl WHERE kl.kirtan_id = k.id AND INSTR(kl.line_text, ?) > 0 LIMIT 1)';

    if (isMultiWord) {
      execParams.add(consecutivePhrase);
    }
    execParams.add(primaryToken);
    execParams.addAll(params);

    final orderBySql = isMultiWord
        ? 'ORDER BY phrase_score ASC, k.part_number, k.old_page, k.chapter_number, k.kirtan_number'
        : 'ORDER BY k.part_number, k.old_page, k.chapter_number, k.kirtan_number';

    final sql = '''
      SELECT k.id, k.unique_kirtan_id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
             k.old_page, k.raag, k.raag_normalized, k.title_hi, k.title_en,
             k.raw_first_line, k.source_filename, k.source_anchor,
             c.title_hi AS chapter_title,
             $phraseScoreSql
             $lineSnippetSql AS raw_matched_line,
             0.0 AS rank
      FROM kirtans k
      JOIN chapters c ON k.chapter_id = c.id
      WHERE $whereClause
      $orderBySql
      LIMIT ? OFFSET ?;
    ''';

    execParams.addAll([limit, offset]);
    final rows = await _db.rawQuery(sql, execParams);

    // Build SearchResult list with highlighted snippet
    return rows.map((row) {
      final matchedLine = (row['raw_matched_line'] as String?) ?? '';
      String? snippet;
      if (matchedLine.isNotEmpty) {
        snippet = _highlightSnippetText(matchedLine, tokens);
      }
      return SearchResult(
        id: row['id'] as int,
        uniqueKirtanId: (row['unique_kirtan_id'] as String?) ?? '',
        kirtanUid: row['kirtan_uid'] as String,
        partNumber: row['part_number'] as int,
        chapterNumber: row['chapter_number'] as int,
        chapterTitle: (row['chapter_title'] as String?) ?? (row['chapter_title_hi'] as String?),
        kirtanNumber: row['kirtan_number'] as int,
        oldPage: row['old_page'] as int,
        raag: (row['raag'] as String?) ?? '',
        raagNormalized: (row['raag_normalized'] as String?) ?? '',
        titleHi: row['title_hi'] as String,
        titleEn: (row['title_en'] as String?) ?? '',
        rawFirstLine: (row['raw_first_line'] as String?) ?? '',
        sourceFilename: (row['source_filename'] as String?) ?? '',
        sourceAnchor: (row['source_anchor'] as String?) ?? '',
        matchingSnippet: snippet,
        rank: (row['rank'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  /// Inserts `<mark>...</mark>` tags around matched tokens in the lyric snippet.
  static String _highlightSnippetText(String text, List<String> tokens) {
    if (tokens.isEmpty || text.isEmpty) return text;
    var result = text;
    for (final token in tokens) {
      if (token.isEmpty) continue;
      final escaped = RegExp.escape(token);
      result = result.replaceAllMapped(
        RegExp(escaped, caseSensitive: false),
        (match) => '<mark>${match.group(0)}</mark>',
      );
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Kirtan Details & Lyrics
  // ---------------------------------------------------------------------------

  /// Retrieves complete kirtan record including structured poetic lines.
  Future<Kirtan?> getKirtanById(int kirtanId) async {
    final kRows = await _db.rawQuery('''
      SELECT k.*, c.title_hi AS chapter_title
      FROM kirtans k
      JOIN chapters c ON k.chapter_id = c.id
      WHERE k.id = ?
      LIMIT 1;
    ''', [kirtanId]);
    if (kRows.isEmpty) return null;

    final lineRows = await _db.query(
      'kirtan_lines',
      where: 'kirtan_id = ?',
      whereArgs: [kirtanId],
      orderBy: 'line_number ASC',
    );
    final lines = lineRows.map(KirtanLine.fromMap).toList();
    return Kirtan.fromMap(kRows.first, lines: lines);
  }

  /// Retrieves complete kirtan by canonical UID (e.g. "P1.C1.K1.P1").
  Future<Kirtan?> getKirtanByUid(String uid) async {
    final kRows = await _db.rawQuery('''
      SELECT k.*, c.title_hi AS chapter_title
      FROM kirtans k
      JOIN chapters c ON k.chapter_id = c.id
      WHERE UPPER(k.kirtan_uid) = UPPER(?)
      LIMIT 1;
    ''', [uid.trim()]);
    if (kRows.isEmpty) return null;

    final kirtanId = kRows.first['id'] as int;
    final lineRows = await _db.query(
      'kirtan_lines',
      where: 'kirtan_id = ?',
      whereArgs: [kirtanId],
      orderBy: 'line_number ASC',
    );
    final lines = lineRows.map(KirtanLine.fromMap).toList();
    return Kirtan.fromMap(kRows.first, lines: lines);
  }

  /// Retrieves complete kirtan by canonical unique ID (e.g. "n1541" or "N1541").
  Future<Kirtan?> getKirtanByUniqueId(String uniqueId) async {
    final trimmed = uniqueId.trim();
    final nMatch = RegExp(r'^[nN](\d+)$').firstMatch(trimmed);
    final target = nMatch != null ? 'n${nMatch.group(1)!}' : trimmed.toLowerCase();

    final kRows = await _db.rawQuery('''
      SELECT k.*, c.title_hi AS chapter_title
      FROM kirtans k
      JOIN chapters c ON k.chapter_id = c.id
      WHERE k.unique_kirtan_id = ?
      LIMIT 1;
    ''', [target]);
    if (kRows.isEmpty) return null;

    final kirtanId = kRows.first['id'] as int;
    final lineRows = await _db.query(
      'kirtan_lines',
      where: 'kirtan_id = ?',
      whereArgs: [kirtanId],
      orderBy: 'line_number ASC',
    );
    final lines = lineRows.map(KirtanLine.fromMap).toList();
    return Kirtan.fromMap(kRows.first, lines: lines);
  }

  /// Retrieves the adjacent kirtan ID following the deterministic corpus sequence [order_num].
  /// Supports optional [partNumber] filtering to stay within the current Part.
  Future<int?> getAdjacentKirtanId({
    required int currentOrderNum,
    required bool next,
    int? partNumber,
  }) async {
    if (partNumber != null) {
      final op = next ? '>' : '<';
      final order = next ? 'ASC' : 'DESC';
      final rows = await _db.rawQuery('''
        SELECT id FROM kirtans
        WHERE part_number = ? AND order_num $op ?
        ORDER BY order_num $order
        LIMIT 1;
      ''', [partNumber, currentOrderNum]);
      if (rows.isEmpty) return null;
      return rows.first['id'] as int;
    } else {
      final targetOrder = next ? currentOrderNum + 1 : currentOrderNum - 1;
      if (targetOrder < 1 || targetOrder > 6584) return null;
      final rows = await _db.rawQuery(
        'SELECT id FROM kirtans WHERE order_num = ? LIMIT 1;',
        [targetOrder],
      );
      if (rows.isEmpty) return null;
      return rows.first['id'] as int;
    }
  }

  // ---------------------------------------------------------------------------
  // FTS Sanitization & Query Preparation
  // ---------------------------------------------------------------------------

  static String _prepareLinesFtsQuery(String query) {
    final trimmed = query.trim();
    // If user explicitly provided quotes: e.g. "श्री कृष्ण"
    if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 2) {
      final inner = trimmed.substring(1, trimmed.length - 1).replaceAll('"', ' ').trim();
      return '"$inner"';
    }

    // Strip punctuation
    final cleaned = trimmed.replaceAll(RegExp(r'["\x27\*\(\)\{\}\[\]\^\~]'), ' ').trim();
    if (cleaned.isEmpty) return '';

    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return '';

    // Enforce exact word boundaries for each token with AND
    return tokens.map((t) => '"$t"').join(' AND ');
  }
}

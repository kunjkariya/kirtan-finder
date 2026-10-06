import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';

/// Repository managing user preferences and application settings in SQLite.
class SettingsRepository {
  final DatabaseService _dbService;

  static const String keyReaderFontSize = 'reader_font_size';
  static const double defaultReaderFontSize = 20.0;

  SettingsRepository(this._dbService);

  Database get _db => _dbService.database;

  /// Retrieves the persisted reader font size or returns [defaultReaderFontSize].
  Future<double> getReaderFontSize() async {
    final rows = await _db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [keyReaderFontSize],
      limit: 1,
    );
    if (rows.isEmpty) return defaultReaderFontSize;
    final valStr = rows.first['value'] as String?;
    if (valStr == null) return defaultReaderFontSize;
    return double.tryParse(valStr) ?? defaultReaderFontSize;
  }

  /// Persists the reader font size.
  Future<void> setReaderFontSize(double size) async {
    await _db.rawInsert('''
      INSERT OR REPLACE INTO app_settings (key, value)
      VALUES (?, ?);
    ''', [keyReaderFontSize, size.toString()]);
  }
}

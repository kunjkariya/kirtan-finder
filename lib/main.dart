import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app/app.dart';
import 'core/database/database_service.dart';
import 'core/repositories/folder_repository.dart';
import 'core/repositories/kirtan_repository.dart';
import 'core/repositories/recent_repository.dart';
import 'core/repositories/settings_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On non-web platforms, configure FFI SQLite runtime to use the bundled
  // libsqlite3 engine (which has FTS5, JSON1, and RTREE compiled in).
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
    }
    databaseFactory = databaseFactoryFfi;
  }

  final dbService = DatabaseService();
  await dbService.init();

  final kirtanRepository = KirtanRepository(dbService);
  final folderRepository = FolderRepository(dbService);
  final recentRepository = RecentRepository(dbService);
  final settingsRepository = SettingsRepository(dbService);

  runApp(
    KirtanFinderApp(
      kirtanRepository: kirtanRepository,
      folderRepository: folderRepository,
      recentRepository: recentRepository,
      settingsRepository: settingsRepository,
    ),
  );
}

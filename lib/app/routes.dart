import 'package:flutter/material.dart';
import '../core/repositories/folder_repository.dart';
import '../core/repositories/kirtan_repository.dart';
import '../core/repositories/recent_repository.dart';
import '../core/repositories/settings_repository.dart';
import '../features/favourites/folder_screen.dart';
import '../features/kirtan/kirtan_screen.dart';
import '../features/kirtan/shared_kirtan_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String kirtanDetail = '/kirtan';
  static const String folderDetail = '/folder';

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings, {
    KirtanRepository? kirtanRepo,
    FolderRepository? folderRepo,
    RecentRepository? recentRepo,
    SettingsRepository? settingsRepo,
  }) {
    final routeName = settings.name ?? '';

    // Handle deep links like /kirtan/n1541 or /kirtan/N1541
    if (routeName.startsWith('/kirtan/')) {
      final shareId = routeName.substring('/kirtan/'.length);
      if (kirtanRepo != null && folderRepo != null) {
        return MaterialPageRoute(
          builder: (_) => SharedKirtanScreen(
            rawShareId: shareId,
            kirtanRepository: kirtanRepo,
            folderRepository: folderRepo,
            recentRepository: recentRepo,
            settingsRepository: settingsRepo,
          ),
          settings: settings,
        );
      }
    }

    switch (settings.name) {
      case kirtanDetail:
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final kirtanId = args['kirtanId'] as int;
          final highlightQuery = args['highlightQuery'] as String?;
          final partNumber = args['partNumber'] as int?;
          return MaterialPageRoute(
            builder: (_) => KirtanScreen(
              kirtanId: kirtanId,
              kirtanRepository: kirtanRepo,
              folderRepository: folderRepo,
              recentRepository: recentRepo,
              settingsRepository: settingsRepo,
              highlightQuery: highlightQuery,
              partNumber: partNumber,
            ),
            settings: settings,
          );
        } else if (settings.arguments is String && kirtanRepo != null && folderRepo != null) {
          // Route argument passed as public ID string: e.g. "n1541"
          return MaterialPageRoute(
            builder: (_) => SharedKirtanScreen(
              rawShareId: settings.arguments as String,
              kirtanRepository: kirtanRepo,
              folderRepository: folderRepo,
              recentRepository: recentRepo,
              settingsRepository: settingsRepo,
            ),
            settings: settings,
          );
        }
        return null;

      case folderDetail:
        final args = settings.arguments as Map<String, dynamic>;
        final folderId = args['folderId'] as int;
        final folderName = args['folderName'] as String;
        return MaterialPageRoute(
          builder: (_) => FolderScreen(
            folderId: folderId,
            folderName: folderName,
            folderRepository: folderRepo,
          ),
          settings: settings,
        );

      default:
        return null;
    }
  }
}

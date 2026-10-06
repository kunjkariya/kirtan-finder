import 'package:flutter/material.dart';
import '../core/repositories/folder_repository.dart';
import '../core/repositories/kirtan_repository.dart';
import '../core/repositories/recent_repository.dart';
import '../core/repositories/settings_repository.dart';
import '../features/favourites/favourites_screen.dart';
import '../features/favourites/folder_screen.dart';
import '../features/kirtan/kirtan_screen.dart';
import '../features/recent/recent_screen.dart';
import '../features/search/search_controller.dart';
import '../features/search/search_screen.dart';
import 'routes.dart';
import 'theme.dart';

/// The root application widget configuring themes, routes, and responsive navigation.
class KirtanFinderApp extends StatelessWidget {
  final KirtanRepository kirtanRepository;
  final FolderRepository folderRepository;
  final RecentRepository? recentRepository;
  final SettingsRepository? settingsRepository;

  const KirtanFinderApp({
    super.key,
    required this.kirtanRepository,
    required this.folderRepository,
    this.recentRepository,
    this.settingsRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kirtan Finder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.kirtanDetail) {
          if (settings.arguments is Map<String, dynamic>) {
            final args = settings.arguments as Map<String, dynamic>;
            final kirtanId = args['kirtanId'] as int;
            final highlightQuery = args['highlightQuery'] as String?;
            final partNumber = args['partNumber'] as int?;
            return MaterialPageRoute(
              builder: (_) => KirtanDetailRoute(
                kirtanId: kirtanId,
                kirtanRepo: kirtanRepository,
                folderRepo: folderRepository,
                recentRepo: recentRepository,
                settingsRepo: settingsRepository,
                highlightQuery: highlightQuery,
                partNumber: partNumber,
              ),
              settings: settings,
            );
          }
        } else if (settings.name == AppRoutes.folderDetail) {
          final args = settings.arguments as Map<String, dynamic>;
          final folderId = args['folderId'] as int;
          final folderName = args['folderName'] as String;
          return MaterialPageRoute(
            builder: (_) => FolderDetailRoute(
              folderId: folderId,
              folderName: folderName,
              folderRepo: folderRepository,
            ),
            settings: settings,
          );
        }
        return AppRoutes.onGenerateRoute(
          settings,
          kirtanRepo: kirtanRepository,
          folderRepo: folderRepository,
          recentRepo: recentRepository,
          settingsRepo: settingsRepository,
        );
      },
      home: MainNavigationScreen(
        kirtanRepository: kirtanRepository,
        folderRepository: folderRepository,
        recentRepository: recentRepository,
        settingsRepository: settingsRepository,
      ),
    );
  }
}

/// Responsive main container adapting between BottomNavigationBar on phones
/// and NavigationRail on iPads/tablets, styled in minimalist monochrome.
/// Navigation: Search | Recent | Saved
class MainNavigationScreen extends StatefulWidget {
  final KirtanRepository kirtanRepository;
  final FolderRepository folderRepository;
  final RecentRepository? recentRepository;
  final SettingsRepository? settingsRepository;

  const MainNavigationScreen({
    super.key,
    required this.kirtanRepository,
    required this.folderRepository,
    this.recentRepository,
    this.settingsRepository,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final SearchPageController _searchController;
  late final RecentRepository _effectiveRecentRepo;

  @override
  void initState() {
    super.initState();
    _searchController = SearchPageController(widget.kirtanRepository);
    _effectiveRecentRepo = widget.recentRepository ?? RecentRepository(widget.kirtanRepository.dbService);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 720;

    final pages = [
      SearchScreen(controller: _searchController),
      RecentScreen(
        recentRepository: _effectiveRecentRepo,
        kirtanRepository: widget.kirtanRepository,
        folderRepository: widget.folderRepository,
        settingsRepository: widget.settingsRepository,
      ),
      FavouritesScreen(folderRepository: widget.folderRepository),
    ];

    if (isTablet) {
      // iPad / Tablet layout: Monochrome NavigationRail on the left
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: theme.scaffoldBackgroundColor,
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              labelType: NavigationRailLabelType.all,
              indicatorColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.search),
                  selectedIcon: Icon(
                    Icons.search,
                    color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                  ),
                  label: const Text('Search'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.history_rounded),
                  selectedIcon: Icon(
                    Icons.history_rounded,
                    color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                  ),
                  label: const Text('Recent'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.bookmark_outline),
                  selectedIcon: Icon(
                    Icons.bookmark,
                    color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                  ),
                  label: const Text('Saved'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: pages[_currentIndex]),
          ],
        ),
      );
    }

    // Phone layout: Clean monochrome NavigationBar (Search | Recent | Saved)
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Recent',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}

class KirtanDetailRoute extends StatelessWidget {
  final int kirtanId;
  final KirtanRepository kirtanRepo;
  final FolderRepository folderRepo;
  final RecentRepository? recentRepo;
  final SettingsRepository? settingsRepo;
  final String? highlightQuery;
  final int? partNumber;

  const KirtanDetailRoute({
    super.key,
    required this.kirtanId,
    required this.kirtanRepo,
    required this.folderRepo,
    this.recentRepo,
    this.settingsRepo,
    this.highlightQuery,
    this.partNumber,
  });

  @override
  Widget build(BuildContext context) {
    return KirtanScreen(
      kirtanId: kirtanId,
      kirtanRepository: kirtanRepo,
      folderRepository: folderRepo,
      recentRepository: recentRepo,
      settingsRepository: settingsRepo,
      highlightQuery: highlightQuery,
      partNumber: partNumber,
    );
  }
}

class FolderDetailRoute extends StatelessWidget {
  final int folderId;
  final String folderName;
  final FolderRepository folderRepo;

  const FolderDetailRoute({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.folderRepo,
  });

  @override
  Widget build(BuildContext context) {
    return FolderScreen(
      folderId: folderId,
      folderName: folderName,
      folderRepository: folderRepo,
    );
  }
}

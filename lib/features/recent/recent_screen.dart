import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/models/search_result.dart';
import '../../core/repositories/folder_repository.dart';
import '../../core/repositories/kirtan_repository.dart';
import '../../core/repositories/recent_repository.dart';
import '../../core/repositories/settings_repository.dart';
import '../search/widgets/search_result_tile.dart';

/// Screen displaying the user's recently opened kirtans in reverse chronological order.
///
/// Features:
/// - Uses the same search-result card aesthetic (SearchResultTile).
/// - Shows public ID, Hindi title, English transliteration, Part · Chapter Title · Page · Raag.
/// - Maximum 20 unique items.
/// - Clear action with confirmation dialog.
/// - Clean empty state when no kirtans have been opened yet.
class RecentScreen extends StatefulWidget {
  final RecentRepository recentRepository;
  final KirtanRepository kirtanRepository;
  final FolderRepository folderRepository;
  final SettingsRepository? settingsRepository;

  const RecentScreen({
    super.key,
    required this.recentRepository,
    required this.kirtanRepository,
    required this.folderRepository,
    this.settingsRepository,
  });

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  List<SearchResult> _recentList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    setState(() => _isLoading = true);
    final items = await widget.recentRepository.getRecentKirtans();
    if (mounted) {
      setState(() {
        _recentList = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmClearRecent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clear recently opened kirtans?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Clear',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.recentRepository.clearRecent();
      await _loadRecent();
    }
  }

  void _openKirtan(SearchResult item) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.kirtanDetail,
      arguments: {
        'kirtanId': item.id,
        'partNumber': item.partNumber,
      },
    );
    // Reload recent list when returning
    if (mounted) {
      _loadRecent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent'),
        actions: [
          if (_recentList.isNotEmpty)
            TextButton(
              onPressed: _confirmClearRecent,
              child: Text(
                'Clear',
                style: TextStyle(
                  color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _recentList.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadRecent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: _recentList.length,
                    itemBuilder: (context, index) {
                      final item = _recentList[index];
                      return SearchResultTile(
                        result: item,
                        onTap: () => _openKirtan(item),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 56,
              color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
            ),
            const SizedBox(height: 18),
            const Text(
              'Recently Opened',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No recently opened kirtans yet.\nOpen a kirtan to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/models/search_result.dart';
import '../../core/repositories/folder_repository.dart';
import '../search/widgets/search_result_tile.dart';

/// Screen listing all kirtans bookmarked within a specific folder.
/// Supports drag-and-drop reordering that persists permanently to SQLite,
/// removing kirtans from the folder, and navigating to full reading view.
class FolderScreen extends StatefulWidget {
  final int folderId;
  final String folderName;
  final FolderRepository? folderRepository;

  const FolderScreen({
    super.key,
    required this.folderId,
    required this.folderName,
    this.folderRepository,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  List<SearchResult> _kirtans = [];
  bool _isLoading = true;
  late final FolderRepository _folderRepo;

  @override
  void initState() {
    super.initState();
    _folderRepo = widget.folderRepository!;
    _loadKirtans();
  }

  Future<void> _loadKirtans() async {
    setState(() => _isLoading = true);
    final list = await _folderRepo.getFolderKirtans(widget.folderId);
    if (mounted) {
      setState(() {
        _kirtans = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _onReorderKirtans(int oldIndex, int newIndex) async {
    setState(() {
      final item = _kirtans.removeAt(oldIndex);
      _kirtans.insert(newIndex, item);
    });

    await _folderRepo.updateKirtanOrder(widget.folderId, _kirtans.map((k) => k.id).toList());
    final updated = await _folderRepo.getFolderKirtans(widget.folderId);
    if (mounted) {
      setState(() {
        _kirtans = updated;
      });
    }
  }

  Future<void> _removeKirtan(SearchResult kirtan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text('Remove "${kirtan.titleHi}" from ${widget.folderName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _folderRepo.removeFromFolder(widget.folderId, kirtan.id);
      _loadKirtans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFavorites = widget.folderId == FolderRepository.favoritesFolderId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.folderName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (!_isLoading)
              Text(
                '${_kirtans.length} ${_kirtans.length == 1 ? "kirtan" : "kirtans"}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                ),
              ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _kirtans.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isFavorites ? Icons.bookmark_outline : Icons.folder_open,
                              size: 56,
                              color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isFavorites ? 'No saved kirtans yet' : 'This folder is empty',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isFavorites
                                  ? 'Tap the bookmark icon on any kirtan to save it here.'
                                  : 'Save kirtans to this folder from the reader screen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadKirtans,
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: _kirtans.length,
                        onReorderItem: _onReorderKirtans,
                        itemBuilder: (context, index) {
                          final item = _kirtans[index];
                          return Container(
                            key: ValueKey('kirtan_${item.id}'),
                            child: SearchResultTile(
                              result: item,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle_outline,
                                      size: 18,
                                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                                    ),
                                    tooltip: 'Remove from folder',
                                    onPressed: () => _removeKirtan(item),
                                  ),
                                  Icon(
                                    Icons.drag_handle,
                                    size: 20,
                                    color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.kirtanDetail,
                                  arguments: {'kirtanId': item.id},
                                ).then((_) => _loadKirtans());
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}

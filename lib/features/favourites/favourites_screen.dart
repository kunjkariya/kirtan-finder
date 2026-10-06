import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/models/folder.dart';
import '../../core/repositories/folder_repository.dart';

/// Screen listing all folders in custom sort order with drag-and-drop reordering,
/// folder creation, renaming, and safe deletion in clean monochrome styling.
class FavouritesScreen extends StatefulWidget {
  final FolderRepository folderRepository;

  const FavouritesScreen({super.key, required this.folderRepository});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<Folder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    final list = await widget.folderRepository.getFoldersOrdered();
    if (mounted) {
      setState(() {
        _folders = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _onReorderFolders(int oldIndex, int newIndex) async {
    setState(() {
      final item = _folders.removeAt(oldIndex);
      _folders.insert(newIndex, item);
    });

    await widget.folderRepository.updateFolderOrder(_folders.map((f) => f.id).toList());
    final updated = await widget.folderRepository.getFoldersOrdered();
    if (mounted) {
      setState(() {
        _folders = updated;
      });
    }
  }

  Future<void> _createNewFolder() async {
    final textController = TextEditingController();
    String? validationError;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLength: 60,
                  decoration: InputDecoration(
                    hintText: 'Folder name (e.g. Morning, Janmashtami...)',
                    errorText: validationError,
                  ),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final trimmed = textController.text.trim();
                  if (trimmed.isEmpty) {
                    setDialogState(() => validationError = 'Folder name cannot be empty');
                    return;
                  }
                  if (_folders.any((f) => f.name.toLowerCase() == trimmed.toLowerCase())) {
                    setDialogState(() => validationError = 'A folder with this name already exists');
                    return;
                  }
                  Navigator.pop(ctx, trimmed);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await widget.folderRepository.createFolder(name);
      _loadFolders();
    }
  }

  Future<void> _renameFolder(Folder folder) async {
    final textController = TextEditingController(text: folder.name);
    String? validationError;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Rename Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: TextField(
              controller: textController,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: 'Enter new name',
                errorText: validationError,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final trimmed = textController.text.trim();
                  if (trimmed.isEmpty) {
                    setDialogState(() => validationError = 'Folder name cannot be empty');
                    return;
                  }
                  Navigator.pop(ctx, trimmed);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != folder.name) {
      await widget.folderRepository.renameFolder(folder.id, newName);
      _loadFolders();
    }
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: const Text(
          'Are you sure you want to delete this folder?\n'
          'Kirtans inside will remain safe in the library.',
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.folderRepository.deleteFolder(folder.id);
      _loadFolders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Folders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _folders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 56,
                            color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No folders yet',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _createNewFolder,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create Folder'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFolders,
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        itemCount: _folders.length,
                        onReorderItem: _onReorderFolders,
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          final isFavorites = folder.id == FolderRepository.favoritesFolderId || folder.isSystem;

                          return Card(
                            key: ValueKey('folder_${folder.id}'),
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: Icon(
                                  isFavorites ? Icons.bookmark : Icons.folder_outlined,
                                  size: 18,
                                  color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      folder.name,
                                      style: TextStyle(
                                        fontWeight: isFavorites ? FontWeight.w700 : FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (isFavorites) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF6E6E73),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${folder.kirtanCount} ${folder.kirtanCount == 1 ? "kirtan" : "kirtans"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isFavorites)
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                                      ),
                                      tooltip: 'Folder options',
                                      onSelected: (value) {
                                        if (value == 'rename') {
                                          _renameFolder(folder);
                                        } else if (value == 'delete') {
                                          _confirmDeleteFolder(folder);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'rename',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 18),
                                              SizedBox(width: 10),
                                              Text('Rename'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Theme.of(context).colorScheme.error,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Delete',
                                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
                                  AppRoutes.folderDetail,
                                  arguments: {
                                    'folderId': folder.id,
                                    'folderName': folder.name,
                                  },
                                ).then((_) => _loadFolders());
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewFolder,
        tooltip: 'New Folder',
        backgroundColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111),
        foregroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        child: const Icon(Icons.add),
      ),
    );
  }
}

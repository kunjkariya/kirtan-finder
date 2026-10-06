import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/kirtan.dart';
import '../../core/repositories/folder_repository.dart';
import '../../core/repositories/kirtan_repository.dart';
import '../../core/repositories/recent_repository.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/services/share_service.dart';
import 'widgets/kirtan_header.dart';
import 'widgets/kirtan_lyrics.dart';

/// Screen displaying complete details, authentic structured lyrics,
/// quick 1-tap favorite toggle, multi-folder management, font size adjustment,
/// and sequential corpus navigation for a selected kirtan.
class KirtanScreen extends StatefulWidget {
  final int kirtanId;
  final KirtanRepository? kirtanRepository;
  final FolderRepository? folderRepository;
  final RecentRepository? recentRepository;
  final SettingsRepository? settingsRepository;
  final String? highlightQuery;
  final int? partNumber;

  const KirtanScreen({
    super.key,
    required this.kirtanId,
    this.kirtanRepository,
    this.folderRepository,
    this.recentRepository,
    this.settingsRepository,
    this.highlightQuery,
    this.partNumber,
  });

  @override
  State<KirtanScreen> createState() => _KirtanScreenState();
}

class _KirtanScreenState extends State<KirtanScreen> {
  late int _activeKirtanId;
  Kirtan? _kirtan;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFavorite = false;
  bool _isBookmarked = false;
  List<int> _savedFolderIds = [];
  double _fontSize = 20.0;
  int? _prevKirtanId;
  int? _nextKirtanId;
  Timer? _highlightTimer;
  String? _activeHighlightQuery;

  late final KirtanRepository _kirtanRepo;
  late final FolderRepository _folderRepo;

  @override
  void initState() {
    super.initState();
    _activeKirtanId = widget.kirtanId;
    _kirtanRepo = widget.kirtanRepository!;
    _folderRepo = widget.folderRepository!;
    _activeHighlightQuery = widget.highlightQuery;
    if (_activeHighlightQuery != null && _activeHighlightQuery!.trim().isNotEmpty) {
      _startHighlightTimer();
    }
    _initFontSize();
    _loadKirtan(_activeKirtanId, isInitial: true);
  }

  void _startHighlightTimer() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        setState(() {
          _activeHighlightQuery = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    super.dispose();
  }

  Future<void> _initFontSize() async {
    if (widget.settingsRepository != null) {
      final savedSize = await widget.settingsRepository!.getReaderFontSize();
      if (mounted) {
        setState(() => _fontSize = savedSize);
      }
    }
  }

  Future<void> _loadKirtan(int id, {bool isInitial = false}) async {
    if (!isInitial) {
      _highlightTimer?.cancel();
      _highlightTimer = null;
      _activeHighlightQuery = null;
    }

    setState(() {
      _activeKirtanId = id;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final k = await _kirtanRepo.getKirtanById(id);
      final folderIds = await _folderRepo.getFoldersForKirtan(id);

      int? prevId;
      int? nextId;
      if (k != null) {
        prevId = await _kirtanRepo.getAdjacentKirtanId(
          currentOrderNum: k.orderNum,
          next: false,
          partNumber: widget.partNumber,
        );
        nextId = await _kirtanRepo.getAdjacentKirtanId(
          currentOrderNum: k.orderNum,
          next: true,
          partNumber: widget.partNumber,
        );
      }

      if (mounted) {
        setState(() {
          _kirtan = k;
          _savedFolderIds = folderIds;
          _isFavorite = folderIds.contains(FolderRepository.favoritesFolderId);
          _isBookmarked = folderIds.isNotEmpty;
          _prevKirtanId = prevId;
          _nextKirtanId = nextId;
          _isLoading = false;
        });
        if (k != null) {
          widget.recentRepository?.recordOpened(k.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load kirtan: $e';
        });
      }
    }
  }

  Future<void> _toggleQuickFavorite() async {
    final newStatus = await _folderRepo.toggleFavorite(_activeKirtanId);
    if (!mounted) return;
    setState(() {
      _isFavorite = newStatus;
      if (newStatus) {
        if (!_savedFolderIds.contains(FolderRepository.favoritesFolderId)) {
          _savedFolderIds.add(FolderRepository.favoritesFolderId);
        }
      } else {
        _savedFolderIds.remove(FolderRepository.favoritesFolderId);
      }
      _isBookmarked = _savedFolderIds.isNotEmpty;
    });
  }

  void _showBookmarkSheet() async {
    if (_kirtan == null) return;

    final folders = await _folderRepo.getFoldersOrdered();
    if (!mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bookmark_add_outlined,
                          size: 22,
                          color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Save to Folder',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (folders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No folders available'),
                      )
                    else
                      ...folders.map((folder) {
                        final inFolder = _savedFolderIds.contains(folder.id);
                        final isFav = folder.id == FolderRepository.favoritesFolderId;
                        return CheckboxListTile(
                          secondary: Icon(
                            isFav ? Icons.star : Icons.folder_outlined,
                            size: 20,
                            color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                          ),
                          title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${folder.kirtanCount} ${folder.kirtanCount == 1 ? "kirtan" : "kirtans"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                            ),
                          ),
                          value: inFolder,
                          activeColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                          checkColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                          onChanged: (bool? checked) async {
                            if (checked == true) {
                              await _folderRepo.addToFolder(folder.id, _activeKirtanId);
                              _savedFolderIds.add(folder.id);
                            } else {
                              await _folderRepo.removeFromFolder(folder.id, _activeKirtanId);
                              _savedFolderIds.remove(folder.id);
                            }
                            setSheetState(() {});
                            setState(() {
                              _isFavorite = _savedFolderIds.contains(FolderRepository.favoritesFolderId);
                              _isBookmarked = _savedFolderIds.isNotEmpty;
                            });
                          },
                        );
                      }),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111),
                        foregroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                      ),
                      onPressed: () async {
                        final name = await _promptNewFolderName(ctx);
                        if (name != null && name.trim().isNotEmpty) {
                          final newFolder = await _folderRepo.createFolder(name);
                          await _folderRepo.addToFolder(newFolder.id, _activeKirtanId);
                          _savedFolderIds.add(newFolder.id);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          setState(() {
                            _isFavorite = _savedFolderIds.contains(FolderRepository.favoritesFolderId);
                            _isBookmarked = true;
                          });
                        }
                      },
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('New Folder'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _promptNewFolderName(BuildContext ctx) async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (dCtx) {
        return AlertDialog(
          title: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(hintText: 'Folder name (e.g. Morning, Janmashtami...)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, textController.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showTextSizeSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Text Size',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_fontSize.toInt()} px',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF3A3A3C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          icon: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: _fontSize > 16.0
                              ? () {
                                  final newSize = (_fontSize - 2.0).clamp(16.0, 28.0);
                                  setSheetState(() => _fontSize = newSize);
                                  setState(() => _fontSize = newSize);
                                  widget.settingsRepository?.setReaderFontSize(newSize);
                                }
                              : null,
                        ),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 16.0,
                            max: 28.0,
                            divisions: 6,
                            activeColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111),
                            inactiveColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            onChanged: (val) {
                              setSheetState(() => _fontSize = val);
                              setState(() => _fontSize = val);
                              widget.settingsRepository?.setReaderFontSize(val);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          onPressed: _fontSize < 28.0
                              ? () {
                                  final newSize = (_fontSize + 2.0).clamp(16.0, 28.0);
                                  setSheetState(() => _fontSize = newSize);
                                  setState(() => _fontSize = newSize);
                                  widget.settingsRepository?.setReaderFontSize(newSize);
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _copyKirtanText() async {
    if (_kirtan == null) return;

    final buffer = StringBuffer();
    buffer.writeln('${_kirtan!.uniqueKirtanId}: ${_kirtan!.titleHi}');
    if (_kirtan!.titleEn.isNotEmpty && _kirtan!.titleEn != _kirtan!.titleHi) {
      buffer.writeln(_kirtan!.titleEn);
    }
    final chDisplay = (_kirtan!.chapterTitle != null && _kirtan!.chapterTitle!.isNotEmpty)
        ? _kirtan!.chapterTitle!
        : 'Ch ${_kirtan!.chapterNumber}';
    buffer.write('Part ${_kirtan!.partNumber} | $chDisplay • Kirtan ${_kirtan!.kirtanNumber} | Page: ${_kirtan!.oldPage}');
    if (_kirtan!.raagNormalized.isNotEmpty) {
      buffer.write(' | Raag: ${_kirtan!.raagNormalized}');
    }
    buffer.writeln('\n');

    for (final line in _kirtan!.lines) {
      buffer.write(line.lineText);
      if (line.verseMarker != null && line.verseMarker!.isNotEmpty) {
        buffer.write('  ${line.verseMarker}');
      }
      buffer.writeln();
      if (line.isVerseEnd) {
        buffer.writeln();
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kirtan copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareKirtan() {
    if (_kirtan == null) return;
    ShareService.shareKirtan(
      titleHi: _kirtan!.titleHi,
      uniqueKirtanId: _kirtan!.uniqueKirtanId,
    );
  }

  Future<void> _openYouTube() async {
    if (_kirtan?.youtubeUrl == null) return;
    final uri = Uri.tryParse(_kirtan!.youtubeUrl!);
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open YouTube link')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open YouTube link')),
          );
        }
      }
    }
  }

  void _showSourceInfoDialog() {
    if (_kirtan == null) return;
    final chDisplay = (_kirtan!.chapterTitle != null && _kirtan!.chapterTitle!.isNotEmpty)
        ? '${_kirtan!.chapterNumber} (${_kirtan!.chapterTitle})'
        : '${_kirtan!.chapterNumber}';
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_kirtan!.uniqueKirtanId, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Order', '${_kirtan!.orderNum} / 6584'),
              _infoRow('Part', '${_kirtan!.partNumber}'),
              _infoRow('Chapter', chDisplay),
              _infoRow('Kirtan', '${_kirtan!.kirtanNumber}'),
              _infoRow('Page', '${_kirtan!.oldPage}'),
              _infoRow('Source File', _kirtan!.sourceFilename),
              _infoRow('Anchor', '#${_kirtan!.sourceAnchor}'),
              _infoRow('UID', _kirtan!.kirtanUid),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _kirtan != null ? _kirtan!.uniqueKirtanId : 'Kirtan Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_kirtan != null) ...[
            // Text size adjuster
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.format_size_rounded),
              tooltip: 'Text Size',
              onPressed: _showTextSizeSheet,
            ),
            // Copy action
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy',
              onPressed: _copyKirtanText,
            ),
            // Share Kirtan action
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Kirtan',
              onPressed: _shareKirtan,
            ),
            // 1-Tap Quick Favorite toggle
            Semantics(
              label: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              button: true,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                key: const ValueKey('quick_favorite_button'),
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                ),
                tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: _toggleQuickFavorite,
              ),
            ),
            // Multi-folder bookmark manager
            Semantics(
              label: _isBookmarked ? 'Saved' : 'Save',
              button: true,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                key: const ValueKey('folder_bookmark_button'),
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                ),
                tooltip: 'Save to folder',
                onPressed: _showBookmarkSheet,
              ),
            ),
            // More options popup: YouTube and Source Info
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'youtube') _openYouTube();
                if (val == 'source') _showSourceInfoDialog();
              },
              itemBuilder: (ctx) => [
                if (_kirtan!.youtubeUrl != null && _kirtan!.youtubeUrl!.trim().isNotEmpty)
                  const PopupMenuItem(
                    value: 'youtube',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline, size: 18),
                        SizedBox(width: 10),
                        Text('Search on YouTube'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'source',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 10),
                      Text('Source Details'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _kirtan != null ? _buildBottomNavigation(theme, isDark) : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _loadKirtan(_activeKirtanId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_kirtan == null) {
      return const Center(child: Text('Kirtan not found'));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KirtanHeader(kirtan: _kirtan!),
              KirtanLyrics(
                lines: _kirtan!.lines,
                fontSize: _fontSize,
                highlightQuery: _activeHighlightQuery,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(ThemeData theme, bool isDark) {
    return SafeArea(
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
              ),
              onPressed: _prevKirtanId != null ? () => _loadKirtan(_prevKirtanId!) : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('Previous'),
            ),
            Flexible(
              child: Text(
                '${_kirtan!.uniqueKirtanId.replaceFirst(RegExp(r'^[nN]'), '')} / 6584',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
              ),
              onPressed: _nextKirtanId != null ? () => _loadKirtan(_nextKirtanId!) : null,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

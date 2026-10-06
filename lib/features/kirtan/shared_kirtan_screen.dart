import 'package:flutter/material.dart';
import '../../core/repositories/folder_repository.dart';
import '../../core/repositories/kirtan_repository.dart';
import '../../core/repositories/recent_repository.dart';
import '../../core/repositories/settings_repository.dart';
import '../../core/services/share_service.dart';
import 'kirtan_screen.dart';

/// Screen that resolves an incoming shared deep link or public ID (e.g. /kirtan/n1541).
///
/// If found:
/// - Opens the standard KirtanScreen (which records to Recently Opened).
/// - Normal reader actions (Favorite, Add to Folder, Share, Copy, Prev/Next) remain active.
///
/// If not found (e.g. n99999):
/// - Displays a clean, user-friendly "Kirtan Not Found" screen with a "Back to Search" button.
/// - Never exposes raw DatabaseExceptions or SQL errors.
class SharedKirtanScreen extends StatefulWidget {
  final String rawShareId;
  final KirtanRepository kirtanRepository;
  final FolderRepository folderRepository;
  final RecentRepository? recentRepository;
  final SettingsRepository? settingsRepository;

  const SharedKirtanScreen({
    super.key,
    required this.rawShareId,
    required this.kirtanRepository,
    required this.folderRepository,
    this.recentRepository,
    this.settingsRepository,
  });

  @override
  State<SharedKirtanScreen> createState() => _SharedKirtanScreenState();
}

class _SharedKirtanScreenState extends State<SharedKirtanScreen> {
  bool _isResolving = true;
  int? _resolvedKirtanId;

  @override
  void initState() {
    super.initState();
    _resolveKirtan();
  }

  Future<void> _resolveKirtan() async {
    setState(() {
      _isResolving = true;
    });

    final extractedId = ShareService.extractKirtanId(widget.rawShareId);
    if (extractedId == null) {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
      return;
    }

    try {
      final kirtan = await widget.kirtanRepository.getKirtanByUniqueId(extractedId);
      if (!mounted) return;

      if (kirtan != null) {
        setState(() {
          _resolvedKirtanId = kirtan.id;
          _isResolving = false;
        });
      } else {
        setState(() {
          _isResolving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_resolvedKirtanId != null) {
      return KirtanScreen(
        kirtanId: _resolvedKirtanId!,
        kirtanRepository: widget.kirtanRepository,
        folderRepository: widget.folderRepository,
        recentRepository: widget.recentRepository,
        settingsRepository: widget.settingsRepository,
      );
    }

    // "Kirtan Not Found" user-friendly error state
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kirtan Not Found'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Kirtan Not Found',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This kirtan could not be found in your current Kirtan Finder database.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                    foregroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'Back to Search',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Service handling Kirtan sharing and deep link generation/resolution.
///
/// NOTE on Universal / App Links:
/// Full production deep link handling (assetlinks.json on Android, apple-app-site-association on iOS)
/// requires domain ownership and deployment of verification files to https://kirtanfinder.app.
/// The domain is configurable via [baseUrl] so it can be updated to the final production domain.
class ShareService {
  /// Default conceptual base URL. Configurable at runtime or deployment.
  static String baseUrl = 'https://kirtanfinder.app';

  /// Generates the canonical deep link for a given public Kirtan ID (e.g. n1541).
  static String buildShareUrl(String uniqueKirtanId) {
    return '$baseUrl/kirtan/$uniqueKirtanId';
  }

  /// Builds the standard share message payload:
  /// `Hindi title`
  /// Kirtan ID: n1541
  /// https://kirtanfinder.app/kirtan/n1541
  static String buildShareText({
    required String titleHi,
    required String uniqueKirtanId,
  }) {
    final link = buildShareUrl(uniqueKirtanId);
    return '$titleHi\nKirtan ID: $uniqueKirtanId\n$link';
  }

  /// Triggers the native platform share sheet.
  static Future<void> shareKirtan({
    required String titleHi,
    required String uniqueKirtanId,
  }) async {
    final text = buildShareText(
      titleHi: titleHi,
      uniqueKirtanId: uniqueKirtanId,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: titleHi),
      );
    } catch (e) {
      debugPrint('ShareService: share error ($e)');
    }
  }

  /// Extracts the canonical public Kirtan ID (e.g. "n1541") from a deep link or raw path.
  /// Matches exact format: /kirtan/n1541 or /kirtan/N1541 or n1541 or N1541.
  /// Strict matching: n1541 does not match n15410.
  static String? extractKirtanId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Check for direct ID (e.g. "n1541" or "N1541")
    final directMatch = RegExp(r'^[nN](\d+)$').firstMatch(trimmed);
    if (directMatch != null) {
      return 'n${directMatch.group(1)}';
    }

    // Check for URL or path containing /kirtan/n1541
    final urlMatch = RegExp(r'/kirtan/[nN](\d+)(?:[/?#]|$)').firstMatch(trimmed);
    if (urlMatch != null) {
      return 'n${urlMatch.group(1)}';
    }

    // Try Uri parse
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final segments = uri.pathSegments;
      final kirtanIndex = segments.indexOf('kirtan');
      if (kirtanIndex >= 0 && kirtanIndex + 1 < segments.length) {
        final idCandidate = segments[kirtanIndex + 1];
        final idMatch = RegExp(r'^[nN](\d+)$').firstMatch(idCandidate);
        if (idMatch != null) {
          return 'n${idMatch.group(1)}';
        }
      }
    }

    return null;
  }
}

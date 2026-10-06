# Kirtan Finder (कीर्तन फाइंडर)

[![Latest Release](https://img.shields.io/github/v/release/kunjkariya/kirtan-finder?color=blue&logo=github)](https://github.com/kunjkariya/kirtan-finder/releases/latest)
[![Download APK](https://img.shields.io/badge/Download%20APK-v1.0.0%20(65%20MB)-34D399?logo=android&logoColor=white)](https://github.com/kunjkariya/kirtan-finder/releases/download/v1.0.0/kirtan-finder-v1.0.0.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20iPadOS-4E4E4E)](https://github.com/kunjkariya/kirtan-finder)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-113%20passed-success)](test/)

**Kirtan Finder** is a high-performance, offline-first mobile and tablet application built with Flutter and SQLite FTS5. It provides instant search and authentic digital reading across all **6,584 sacred Pushtimargiya devotional kirtans** (spanning 4 parts and 409 chapters) from canonical Pushtimarg literature.

---

## 📥 Ready-to-Install APK Download

A pre-built, production-signed Android APK is available directly from GitHub Releases:

| Release Asset | Version | File Size | Target Platform | SHA-256 Checksum |
|---|---|---|---|---|
| [**`kirtan-finder-v1.0.0.apk`**](https://github.com/kunjkariya/kirtan-finder/releases/download/v1.0.0/kirtan-finder-v1.0.0.apk) | `v1.0.0` (build 1) | **64.89 MB** | Android 7.0+ (API 24 to 36) | `91fe9cf8d0b3707e1a1e9beeff43b4540852b2e74b9aa6cc773e7d725d090533` |

### Quick Installation Guide (Android)

1. **Download**: Tap the [**Direct APK Download Link**](https://github.com/kunjkariya/kirtan-finder/releases/download/v1.0.0/kirtan-finder-v1.0.0.apk) on your Android device (Samsung Galaxy S23, Google Pixel, OnePlus, Xiaomi, etc.).
2. **Open**: Tap the downloaded file in your browser or Files app.
3. **Install**: If prompted, allow *“Install unknown apps”* for your browser, then tap **Install**.
4. **Offline Use**: The complete 35 MB pre-indexed database is bundled inside the APK. **No internet connection is required after installation.**

---

## Key Highlights

- **Complete Canonical Corpus**: 6,584 authentic kirtans, 409 chapters, and 4 parts indexed with full fidelity to original texts.
- **Dual Specialized Search Engines**:
  - **Search 1 (Titles & Transliterations)**: Substring matching across Hindi titles (`title_hi`), raw poetic first lines (`raw_first_line`), and English transliterations (`title_en`), with page lookups and Part filtering.
  - **Search 2 (Lyric Lines)**: SQLite FTS5 full-text engine searching across 60,000+ poetic lyric lines, with phrase-match relevance ranking prioritizing consecutive word matches first.
- **Canonical Public IDs (`n1` – `n6584`)**: Instant direct lookup by unique sequential identifier without leading zeros (e.g. `n1`, `n1541`, `n6584`), completely case-insensitive (`N1541` = `n1541`).
- **Authentic Reading Experience**:
  - Digital edition typography preserving authentic line breaks, stanza groupings, and verse markers (`॥१॥`, `॥२॥`).
  - Temporary 7-second search highlighting on match navigation that automatically fades to normal text.
  - Sequential corpus navigation (**Previous** / **Next**) following canonical corpus ordering.
  - Persisted custom font-size preferences.
- **Custom Organization & Playlists**:
  - 1-tap quick Favorites.
  - Custom user folders with drag-and-drop manual reordering.
  - Persistent zero-duplication relational references.
- **Recently Opened**:
  - Tracks last 20 opened kirtans with deduplication and most-recent promotion.
- **Sharing**:
  - One-tap formatted share strings with Hindi title, Canonical ID, and deep links.
- **Minimalist Aesthetic**:
  - Restrained monochrome palette (black, white, grey, charcoal) with dark mode and tablet-optimized NavigationRail.

---

## Architecture Overview

Kirtan Finder adheres to clean architectural principles with strict separation of concerns:

```
kirtan-finder/
├── android/                     # Native Android project configuration
├── ios/                         # Native iOS / iPadOS project configuration
├── assets/
│   ├── db/
│   │   └── kirtan_finder.db     # Embedded high-performance SQLite database (FTS5 + B-trees)
│   └── images/
│       └── logo.png             # Application branding asset
├── lib/
│   ├── app/                     # App shell, routing, responsive scaffolds
│   │   ├── app.dart
│   │   ├── routes.dart
│   │   └── theme.dart
│   ├── core/                    # Domain models, database layer, repositories
│   │   ├── database/
│   │   │   ├── database_migrator.dart
│   │   │   └── database_service.dart
│   │   ├── models/
│   │   │   ├── chapter.dart
│   │   │   ├── folder.dart
│   │   │   ├── kirtan.dart
│   │   │   ├── kirtan_line.dart
│   │   │   ├── part.dart
│   │   │   └── search_result.dart
│   │   ├── repositories/
│   │   │   ├── folder_repository.dart
│   │   │   ├── kirtan_repository.dart
│   │   │   ├── recent_repository.dart
│   │   └── settings_repository.dart
│   │   └── services/
│   │       └── share_service.dart
│   └── features/                # UI presentation layer
│       ├── favourites/          # Folders and saved kirtans management
│       ├── kirtan/              # Authenticated digital reader & verse renderer
│       ├── recent/              # Recently opened kirtans screen
│       └── search/              # Real-time search UI and controllers
├── test/                        # 113 comprehensive unit, regression, & widget tests
│   ├── benchmark_search_test.dart
│   ├── favourites_and_folders_test.dart
│   ├── final_release_qa_test.dart
│   ├── reading_experience_test.dart
│   ├── recent_share_chapter_verse_test.dart
│   └── widget_and_flow_test.dart
├── database/                    # Python ETL pipeline & SQLite schema definitions
│   ├── schema.sql
│   ├── importer.py
│   ├── validate_database.py
│   └── benchmark_search.py
└── corpus/                      # 411 canonical XHTML source files (6,584 kirtans)
```

---

## Database Design & Search Engine

The application embeds a pre-compiled, highly indexed SQLite 3 database (`kirtan_finder.db`):

- **Relational Tables**:
  - `parts`: 4 canonical parts of the corpus.
  - `chapters`: 409 chapters with Hindi & English titles.
  - `kirtans`: 6,584 records with `unique_kirtan_id` (`n1`..`n6584`), canonical UID, raag, page, and first line.
  - `kirtan_lines`: 60,000+ poetic verse lines with line sequence, stanza boundary markers, and verse markers.
  - `folders` & `folder_kirtans`: Zero-redundancy relational tables for user-defined playlists with persisted position ordering.
  - `recent_kirtans`: Microsecond-precision timestamped access log capped at 20 items.
- **Search Virtual Tables (FTS5)**:
  - `lines_search_fts`: FTS5 index using the `unicode61` tokenizer (`categories 'L* M* N*'`) for accurate Devanagari matching.
  - Direct fallback query engine ensuring 100% search resilience on platforms with restricted SQLite extensions.

---

## Getting Started (Developers)

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `>= 3.0.0`)
- [Dart SDK](https://dart.dev/get-dart) (version `>= 3.0.0`)
- Android Studio / Android SDK (for Android build)
- Xcode 14+ (for iOS / iPadOS build on macOS)

### Local Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/kunjkariya/kirtan-finder.git
   cd kirtan-finder
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Static Analysis**:
   ```bash
   flutter analyze
   ```

4. **Run the Test Suite (113 tests)**:
   ```bash
   flutter test
   ```

5. **Launch Application Locally**:
   ```bash
   # Run on connected device or simulator
   flutter run
   ```

---

## Building from Source

### Android Release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS Release Bundle

```bash
flutter build ipa --release
```

---

## Corpus & Data Pipeline

If you wish to re-compile or audit the SQLite database from the raw XHTML corpus:

```bash
cd database
python3 importer.py
python3 validate_database.py
python3 benchmark_search.py
```

The pipeline parses all 411 canonical XHTML files located in `corpus/`, validates XML integrity, cleans Devanagari punctuation, structures stanza lines, creates B-tree indexes, and compiles SQLite FTS5 tables with optimization passes.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

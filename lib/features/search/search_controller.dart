import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/models/part.dart';
import '../../core/models/search_result.dart';
import '../../core/repositories/kirtan_repository.dart';
import 'search_state.dart';

/// Controller coordinating search input debouncing, mode selection,
/// Part filtering, and pagination over SQLite FTS5 / SQL queries.
class SearchPageController extends ChangeNotifier {
  final KirtanRepository _repository;
  static const int pageSize = 50;
  static const Duration debounceDuration = Duration(milliseconds: 200);

  SearchState _state = const SearchState();
  Timer? _debounceTimer;

  SearchPageController(this._repository);

  SearchState get state => _state;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Called on search text change. Debounces query execution by ~200ms.
  void onQueryChanged(String query) {
    if (_state.query == query) return;

    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _state = _state.copyWith(
        query: query,
        results: [],
        isLoading: false,
        clearError: true,
        hasReachedEnd: false,
        offset: 0,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(query: query, isLoading: true, clearError: true);
    notifyListeners();

    _debounceTimer = Timer(debounceDuration, () {
      _executeSearch(isNewQuery: true);
    });
  }

  /// Switch between Search 1 (Title / ID) and Search 2 (Kirtan Lines).
  /// Preserves the active Part filter.
  void onModeChanged(SearchMode mode) {
    if (_state.mode == mode) return;

    _debounceTimer?.cancel();
    _state = _state.copyWith(
      mode: mode,
      results: [],
      isLoading: _state.query.trim().isNotEmpty,
      clearError: true,
      hasReachedEnd: false,
      offset: 0,
    );
    notifyListeners();

    if (_state.query.trim().isNotEmpty) {
      _executeSearch(isNewQuery: true);
    }
  }

  /// Changes the active Part filter (All Parts, Part 1, 2, 3, 4).
  void onPartFilterChanged(PartFilter filter) {
    if (_state.partFilter == filter) return;

    _debounceTimer?.cancel();
    _state = _state.copyWith(
      partFilter: filter,
      results: [],
      isLoading: _state.query.trim().isNotEmpty,
      clearError: true,
      hasReachedEnd: false,
      offset: 0,
    );
    notifyListeners();

    if (_state.query.trim().isNotEmpty) {
      _executeSearch(isNewQuery: true);
    }
  }

  /// Clears the active search query.
  void clearSearch() {
    _debounceTimer?.cancel();
    _state = _state.copyWith(
      query: '',
      results: [],
      isLoading: false,
      clearError: true,
      hasReachedEnd: false,
      offset: 0,
    );
    notifyListeners();
  }

  /// Retries the current search query.
  void retry() {
    if (_state.query.trim().isNotEmpty) {
      _state = _state.copyWith(isLoading: true, clearError: true);
      notifyListeners();
      _executeSearch(isNewQuery: true);
    }
  }

  /// Loads the next page of results if available.
  Future<void> loadMore() async {
    if (_state.isLoading || _state.isLoadingMore || _state.hasReachedEnd) return;
    if (_state.query.trim().isEmpty) return;

    _state = _state.copyWith(isLoadingMore: true);
    notifyListeners();

    await _executeSearch(isNewQuery: false);
  }

  Future<void> _executeSearch({required bool isNewQuery}) async {
    final queryText = _state.query.trim();
    if (queryText.isEmpty) {
      _state = _state.copyWith(isLoading: false, isLoadingMore: false);
      notifyListeners();
      return;
    }

    final currentOffset = isNewQuery ? 0 : _state.offset;

    try {
      List<SearchResult> fetched;
      if (_state.mode == SearchMode.titleNumber) {
        fetched = await _repository.searchTitle(
          query: queryText,
          partFilter: _state.partFilter,
          limit: pageSize,
          offset: currentOffset,
        );
      } else {
        fetched = await _repository.searchLines(
          query: queryText,
          partFilter: _state.partFilter,
          limit: pageSize,
          offset: currentOffset,
        );
      }

      final allResults = isNewQuery ? fetched : [..._state.results, ...fetched];
      final reachedEnd = fetched.length < pageSize;

      _state = _state.copyWith(
        results: allResults,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
        hasReachedEnd: reachedEnd,
        offset: currentOffset + fetched.length,
      );
    } catch (e, stack) {
      debugPrint('Search error details: $e\n$stack');
      _state = _state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: 'Something went wrong while searching.',
      );
    }
    notifyListeners();
  }
}

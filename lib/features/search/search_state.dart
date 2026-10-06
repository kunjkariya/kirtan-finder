import '../../core/models/part.dart';
import '../../core/models/search_result.dart';

/// The two distinct, strictly separated search modes.
enum SearchMode {
  titleNumber(
    id: 'titleNumber',
    labelHi: 'Title / ID',
    labelEn: 'Title / ID',
    hintText: 'Search title, ID, or page...',
    description: 'Search title, ID, or page number',
  ),
  lyrics(
    id: 'lyrics',
    labelHi: 'Kirtan Lines',
    labelEn: 'Kirtan Lines',
    hintText: 'Search kirtan lines...',
    description: 'Search only actual kirtan lines',
  );

  final String id;
  final String labelHi;
  final String labelEn;
  final String hintText;
  final String description;

  const SearchMode({
    required this.id,
    required this.labelHi,
    required this.labelEn,
    required this.hintText,
    required this.description,
  });
}

class SearchState {
  final String query;
  final SearchMode mode;
  final PartFilter partFilter;
  final List<SearchResult> results;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final bool hasReachedEnd;
  final int offset;

  const SearchState({
    this.query = '',
    this.mode = SearchMode.titleNumber,
    this.partFilter = PartFilter.all,
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.hasReachedEnd = false,
    this.offset = 0,
  });

  bool get isEmptyQuery => query.trim().isEmpty;
  bool get hasResults => results.isNotEmpty;

  SearchState copyWith({
    String? query,
    SearchMode? mode,
    PartFilter? partFilter,
    List<SearchResult>? results,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    bool? hasReachedEnd,
    int? offset,
  }) {
    return SearchState(
      query: query ?? this.query,
      mode: mode ?? this.mode,
      partFilter: partFilter ?? this.partFilter,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      offset: offset ?? this.offset,
    );
  }
}

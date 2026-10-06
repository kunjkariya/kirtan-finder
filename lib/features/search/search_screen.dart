import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/models/search_result.dart';
import 'search_controller.dart';
import 'search_state.dart';
import 'widgets/part_filter_bar.dart';
import 'widgets/search_mode_selector.dart';
import 'widgets/search_result_tile.dart';

/// The main Search Screen supporting Search 1 (Title / ID) and Search 2 (Kirtan Lines),
/// with shared Part filtering, live debounced querying, and responsive layouts.
class SearchScreen extends StatefulWidget {
  final SearchPageController controller;

  const SearchScreen({super.key, required this.controller});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.loadMore();
    }
  }

  void _onResultTapped(SearchResult result) {
    Navigator.of(context).pushNamed(
      AppRoutes.kirtanDetail,
      arguments: {
        'kirtanId': result.id,
        'highlightQuery': widget.controller.state.mode == SearchMode.lyrics
            ? widget.controller.state.query
            : null,
        'partNumber': widget.controller.state.partFilter.partNumber,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Kirtan Finder',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  // 1. Search Mode Segmented Control
                  SearchModeSelector(
                    selectedMode: state.mode,
                    onModeChanged: (mode) {
                      widget.controller.onModeChanged(mode);
                    },
                  ),

                  // 2. Search Input Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: TextField(
                      controller: _textController,
                      onChanged: widget.controller.onQueryChanged,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                      ),
                      decoration: InputDecoration(
                        hintText: state.mode.hintText,
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                        ),
                        suffixIcon: state.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: 'Clear',
                                onPressed: () {
                                  _textController.clear();
                                  widget.controller.clearSearch();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF6F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Shared Part Filter Bar
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
                    child: PartFilterBar(
                      selectedFilter: state.partFilter,
                      onFilterChanged: widget.controller.onPartFilterChanged,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // 4. Results / States
                  Expanded(
                    child: _buildContent(state),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(SearchState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading && state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Searching...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
              ),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null && state.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 44,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => widget.controller.retry(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmptyQuery) {
      return _buildEmptyQuerySuggestions(state.mode);
    }

    if (state.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
              ),
              const SizedBox(height: 12),
              const Text(
                'No kirtans found',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'No matching kirtans for "${state.query}" in ${state.partFilter.labelEn}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: state.results.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111111),
                ),
              ),
            ),
          );
        }
        final item = state.results[index];
        return SearchResultTile(
          result: item,
          onTap: () => _onResultTapped(item),
        );
      },
    );
  }

  Widget _buildEmptyQuerySuggestions(SearchMode mode) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final suggestions = mode == SearchMode.titleNumber
        ? [
            {'title': 'व्रज भयो', 'desc': 'Hindi title'},
            {'title': 'Vraja Bhayo', 'desc': 'English title'},
            {'title': '25', 'desc': 'Old printed page number'},
            {'title': 'n1', 'desc': 'Public Kirtan ID'},
            {'title': 'n1541', 'desc': 'Public Kirtan ID'},
          ]
        : [
            {'title': 'श्री कृष्ण', 'desc': 'Lyric line search (all words)'},
            {'title': '"श्री कृष्ण"', 'desc': 'Exact phrase search'},
            {'title': 'गोवर्धन', 'desc': 'Specific word in lyric lines'},
          ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
          child: Text(
            mode == SearchMode.titleNumber
                ? 'Search examples'
                : 'Kirtan line search examples',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
              letterSpacing: -0.1,
            ),
          ),
        ),
        ...suggestions.map(
          (s) => Card(
            margin: const EdgeInsets.only(bottom: 6.0),
            child: ListTile(
              dense: true,
              title: Text(
                s['title']!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                s['desc']!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
              ),
              onTap: () {
                _textController.text = s['title']!;
                widget.controller.onQueryChanged(s['title']!);
              },
            ),
          ),
        ),
      ],
    );
  }
}

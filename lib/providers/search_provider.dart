// search_provider.dart — fixed clearQuery method

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../services/music_service.dart';

enum SearchFilter { songs, albums, artists, playlists }

@immutable
class SearchState {
  final String query;
  final SearchFilter filter;
  final List<Track> songResults;
  final List<Album> albumResults;
  final List<ArtistSummary> artistResults;
  final bool isLoading;
  final String? error;
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.filter = SearchFilter.songs,
    this.songResults = const [],
    this.albumResults = const [],
    this.artistResults = const [],
    this.isLoading = false,
    this.error,
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    SearchFilter? filter,
    List<Track>? songResults,
    List<Album>? albumResults,
    List<ArtistSummary>? artistResults,
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<String>? recentSearches,
  }) =>
      SearchState(
        query: query ?? this.query,
        filter: filter ?? this.filter,
        songResults: songResults ?? this.songResults,
        albumResults: albumResults ?? this.albumResults,
        artistResults: artistResults ?? this.artistResults,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        recentSearches: recentSearches ?? this.recentSearches,
      );

  bool get hasResults =>
      songResults.isNotEmpty ||
      albumResults.isNotEmpty ||
      artistResults.isNotEmpty;
}

class SearchNotifier extends StateNotifier<SearchState> {
  final MusicService _musicService = MusicService();
  Timer? _debounce;

  SearchNotifier() : super(const SearchState()) {
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList('recent_searches') ?? [];
    state = state.copyWith(recentSearches: recent);
  }

  Future<void> _saveRecent(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList('recent_searches') ?? [];
    searches.remove(query);
    searches.insert(0, query);
    if (searches.length > 10) searches.removeLast();
    await prefs.setStringList('recent_searches', searches);
    state = state.copyWith(recentSearches: searches);
  }

  void setFilter(SearchFilter filter) {
    state = state.copyWith(filter: filter);
    if (state.query.isNotEmpty) {
      _debounce?.cancel();
      _runSearch(state.query);
    }
  }

  void onQueryChanged(String query) {
    state = state.copyWith(query: query, clearError: true);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = state.copyWith(
        songResults: [],
        albumResults: [],
        artistResults: [],
        isLoading: false,
      );
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 450), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final type = switch (state.filter) {
        SearchFilter.songs => 'songs',
        SearchFilter.albums => 'albums',
        SearchFilter.artists => 'artists',
        SearchFilter.playlists => 'playlists',
      };

      final results = await _musicService.searchWithFilter(query, type);

      switch (state.filter) {
        case SearchFilter.songs:
          state = state.copyWith(
              songResults: results.cast<Track>(), isLoading: false);
        case SearchFilter.albums:
          state = state.copyWith(
              albumResults: results.cast<Album>(), isLoading: false);
        case SearchFilter.artists:
          state = state.copyWith(
              artistResults: results.cast<ArtistSummary>(), isLoading: false);
        case SearchFilter.playlists:
          state = state.copyWith(
              songResults: results.cast<Track>(), isLoading: false);
      }

      if (results.isNotEmpty) await _saveRecent(query.trim());
    } catch (e) {
      debugPrint('Search error: $e');
      state = state.copyWith(
          isLoading: false, error: 'Search failed. Check your connection.');
    }
  }

  void clearQuery() {
    _debounce?.cancel();
    final recent = state.recentSearches;
    state = SearchState(recentSearches: recent);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>(
  (ref) => SearchNotifier(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../services/music_service.dart';

class ArtistSongsState {
  final List<Track> songs;
  final bool isLoading;
  final bool hasReachedMax;
  final int page;
  final String? error;

  ArtistSongsState({
    required this.songs,
    this.isLoading = false,
    this.hasReachedMax = false,
    this.page = 1,
    this.error,
  });

  ArtistSongsState copyWith({
    List<Track>? songs,
    bool? isLoading,
    bool? hasReachedMax,
    int? page,
    String? error,
  }) {
    return ArtistSongsState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      page: page ?? this.page,
      error: error,
    );
  }
}

class ArtistSongsNotifier extends StateNotifier<ArtistSongsState> {
  final String artistId;
  final MusicService _musicService;
  bool _isFetching = false;

  ArtistSongsNotifier(this.artistId, this._musicService) : super(ArtistSongsState(songs: [])) {
    loadMore();
  }

  Future<void> loadMore() async {
    if (_isFetching || state.hasReachedMax) return;
    
    _isFetching = true;
    if (state.songs.isEmpty) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final newSongs = await _musicService.getArtistSongs(artistId, state.page);
      
      if (newSongs.isEmpty) {
        state = state.copyWith(
          hasReachedMax: true,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          songs: [...state.songs, ...newSongs],
          page: state.page + 1,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    } finally {
      _isFetching = false;
    }
  }
}

final artistSongsProvider = StateNotifierProvider.family<ArtistSongsNotifier, ArtistSongsState, String>((ref, artistId) {
  return ArtistSongsNotifier(artistId, MusicService());
});

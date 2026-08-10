import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/api_playlist.dart';
import '../services/user_data_service.dart';

@immutable
class PlaylistState {
  final List<ApiPlaylist> playlists;
  final List<Track> likedSongs;
  final bool isLoading;

  const PlaylistState({
    this.playlists = const [],
    this.likedSongs = const [],
    this.isLoading = false,
  });

  PlaylistState copyWith({
    List<ApiPlaylist>? playlists,
    List<Track>? likedSongs,
    bool? isLoading,
  }) =>
      PlaylistState(
        playlists: playlists ?? this.playlists,
        likedSongs: likedSongs ?? this.likedSongs,
        isLoading: isLoading ?? this.isLoading,
      );

  bool isLiked(Track track) => likedSongs.any((t) => t.videoId == track.videoId);
}

/// Manages user playlists and liked songs — backed by the server (MongoDB).
class PlaylistNotifier extends StateNotifier<PlaylistState> {
  final UserDataService _service = UserDataService();

  PlaylistNotifier() : super(const PlaylistState());

  Future<void> loadUserData() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _service.fetchPlaylists(),
        _service.fetchLikedSongs(),
      ]);
      state = state.copyWith(
        playlists: results[0] as List<ApiPlaylist>,
        likedSongs: results[1] as List<Track>,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Failed to load user data: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void clear() => state = const PlaylistState();

  Future<void> createPlaylist(String name) async {
    final updated = await _service.createPlaylist(name);
    state = state.copyWith(playlists: updated);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final updated = await _service.deletePlaylist(playlistId);
    state = state.copyWith(playlists: updated);
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final updated = await _service.addTrackToPlaylist(playlistId, track);
    state = state.copyWith(
      playlists: [
        for (final p in state.playlists) if (p.id == updated.id) updated else p,
      ],
    );
  }

  Future<void> removeTrackFromPlaylist(String playlistId, Track track) async {
    final updated = await _service.removeTrackFromPlaylist(playlistId, track.videoId);
    state = state.copyWith(
      playlists: [
        for (final p in state.playlists) if (p.id == updated.id) updated else p,
      ],
    );
  }

  Future<void> toggleLiked(Track track) async {
    // Optimistic update
    final wasLiked = state.isLiked(track);
    final optimistic = wasLiked
        ? state.likedSongs.where((t) => t.videoId != track.videoId).toList()
        : [...state.likedSongs, track];
    state = state.copyWith(likedSongs: optimistic);

    try {
      final confirmed = await _service.toggleLikedSong(track);
      state = state.copyWith(likedSongs: confirmed);
    } catch (e) {
      debugPrint('toggleLiked failed, reverting: $e');
      await loadUserData(); // Revert to server state
    }
  }
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, PlaylistState>(
  (ref) => PlaylistNotifier(),
);

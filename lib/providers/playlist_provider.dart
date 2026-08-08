import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/api_playlist.dart';
import '../services/user_data_service.dart';

/// Manages the user's playlists and liked songs — now backed by the
/// server (MongoDB, via UserDataService) instead of local Hive storage,
/// so this data follows the user across devices once they log in.
class PlaylistProvider extends ChangeNotifier {
  final UserDataService _service = UserDataService();

  List<ApiPlaylist> _playlists = [];
  List<Track> _likedSongs = [];
  bool _isLoading = false;

  List<ApiPlaylist> get playlists => _playlists;
  List<Track> get likedSongsTracks => _likedSongs;
  bool get isLoading => _isLoading;

  /// Call after login (or app start if already logged in) to populate
  /// playlists and liked songs from the server.
  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.fetchPlaylists(),
        _service.fetchLikedSongs(),
      ]);
      _playlists = results[0] as List<ApiPlaylist>;
      _likedSongs = results[1] as List<Track>;
    } catch (e) {
      debugPrint('Failed to load user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears in-memory state on logout — does NOT touch server data.
  void clear() {
    _playlists = [];
    _likedSongs = [];
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    _playlists = await _service.createPlaylist(name);
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists = await _service.deletePlaylist(playlistId);
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final updated = await _service.addTrackToPlaylist(playlistId, track);
    _playlists = [
      for (final p in _playlists) if (p.id == updated.id) updated else p,
    ];
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, Track track) async {
    final updated = await _service.removeTrackFromPlaylist(playlistId, track.videoId);
    _playlists = [
      for (final p in _playlists) if (p.id == updated.id) updated else p,
    ];
    notifyListeners();
  }

  bool isLiked(Track track) => _likedSongs.any((t) => t.videoId == track.videoId);

  Future<void> toggleLiked(Track track) async {
    // Optimistic update so the heart icon responds instantly, then
    // reconcile with whatever the server actually returns.
    final wasLiked = isLiked(track);
    if (wasLiked) {
      _likedSongs = _likedSongs.where((t) => t.videoId != track.videoId).toList();
    } else {
      _likedSongs = [..._likedSongs, track];
    }
    notifyListeners();

    try {
      _likedSongs = await _service.toggleLikedSong(track);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to toggle liked song: $e');
      // Revert optimistic update on failure.
      await loadUserData();
    }
  }
}

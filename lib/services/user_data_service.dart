import '../models/track.dart';
import '../models/api_playlist.dart';
import 'api_client.dart';

/// Wraps every backend call related to a logged-in user's data:
/// liked songs, playlists, and watch history. This replaces the old
/// Hive-based local storage now that data lives on the server and is
/// tied to a real account.
class UserDataService {
  final ApiClient _api = ApiClient();

  Future<List<Track>> fetchLikedSongs() async {
    final res = await _api.get('/users/me');
    final liked = (res['likedSongs'] as List)
        .map((t) => Track.fromJson(t as Map<String, dynamic>))
        .toList();
    return liked;
  }

  Future<List<Track>> toggleLikedSong(Track track) async {
    final res = await _api.post('/users/liked-songs/toggle', body: {
      'track': track.toJson(),
    });
    return (res['likedSongs'] as List)
        .map((t) => Track.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<void> logWatchHistory(Track track) async {
    await _api.post('/users/watch-history', body: {'track': track.toJson()});
  }

  Future<List<Track>> fetchWatchHistory() async {
    final res = await _api.get('/users/watch-history');
    final history = res['watchHistory'] as List;
    return history
        .map((entry) => Track.fromJson(entry['track'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiPlaylist>> fetchPlaylists() async {
    final res = await _api.get('/playlists');
    return (res['playlists'] as List)
        .map((p) => ApiPlaylist.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiPlaylist>> createPlaylist(String name) async {
    final res = await _api.post('/playlists', body: {'name': name});
    return (res['playlists'] as List)
        .map((p) => ApiPlaylist.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiPlaylist>> deletePlaylist(String playlistId) async {
    final res = await _api.delete('/playlists/$playlistId');
    return (res['playlists'] as List)
        .map((p) => ApiPlaylist.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<ApiPlaylist> addTrackToPlaylist(String playlistId, Track track) async {
    final res = await _api.post('/playlists/$playlistId/tracks', body: {
      'track': track.toJson(),
    });
    return ApiPlaylist.fromJson(res['playlist'] as Map<String, dynamic>);
  }

  Future<ApiPlaylist> removeTrackFromPlaylist(String playlistId, String videoId) async {
    final res = await _api.delete('/playlists/$playlistId/tracks/$videoId');
    return ApiPlaylist.fromJson(res['playlist'] as Map<String, dynamic>);
  }
}

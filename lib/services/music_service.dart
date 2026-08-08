import '../models/track.dart';
import 'api_client.dart';

/// Connects to our custom Node.js backend to perform JioSaavn searches and
/// extract audio streams. This completely bypasses YouTube!
class MusicService {
  final ApiClient _api = ApiClient();

  /// Search JioSaavn for tracks via the backend proxy
  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // The backend returns a list of simplified song objects
      final results = await _api.get('/music/search?q=${Uri.encodeQueryComponent(query)}');
      
      if (results is! List) return [];

      return results.map((song) {
        return Track(
          videoId: song['videoId'] as String,
          title: song['title'] as String,
          artist: song['artist'] as String,
          thumbnailUrl: song['thumbnailUrl'] as String,
          duration: const Duration(seconds: 180), // Fallback duration, will be updated on stream
        );
      }).toList();
    } catch (e) {
      print('Music search failed: $e');
      return [];
    }
  }

  /// Get the direct audio stream URL from our JioSaavn backend proxy
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final res = await _api.get('/music/stream/$videoId');
      if (res['streamUrl'] != null) {
        return res['streamUrl'] as String;
      }
      throw Exception('Backend returned null streamUrl');
    } catch (e) {
      throw Exception('Failed to get stream for $videoId: $e');
    }
  }

  void dispose() {}
}

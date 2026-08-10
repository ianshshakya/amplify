import '../models/podcast.dart';
import 'api_client.dart';

/// Service for podcast browsing and episode playback via the backend.
class PodcastService {
  static final PodcastService _instance = PodcastService._internal();
  factory PodcastService() => _instance;
  PodcastService._internal();

  final ApiClient _api = ApiClient();

  /// Search for podcasts on YT Music.
  Future<List<Podcast>> searchPodcasts(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = await _api.get(
        '/podcasts/search?q=${Uri.encodeQueryComponent(query)}',
      );
      if (results is! List) return [];
      return results
          .map((p) => Podcast.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get full podcast details including all episodes.
  Future<Podcast?> getPodcast(String channelId) async {
    try {
      final result = await _api.get('/podcasts/$channelId');
      if (result == null) return null;
      return Podcast.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}

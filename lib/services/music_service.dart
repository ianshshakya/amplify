import 'package:flutter/material.dart' show Color;
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/lyrics.dart';
import '../models/mood_category.dart';
import 'api_client.dart';

/// Central service for all music data fetching.
/// Talks to our Node.js backend which uses JioSaavn (saavnapi) for search
/// and direct MP4 stream URL delivery.
class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final ApiClient _api = ApiClient();

  // ─── Search ────────────────────────────────────────────────────────────────

  /// Search JioSaavn for songs. Returns an empty list on any error.
  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = await _api
          .get('/music/search?q=${Uri.encodeQueryComponent(query)}');
      if (results is! List) return [];
      return results
          .map((s) => _trackFromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Search with a specific filter type: 'songs' | 'albums' | 'artists' | 'playlists'
  Future<List<dynamic>> searchWithFilter(String query, String type) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = await _api.get(
        '/music/search?q=${Uri.encodeQueryComponent(query)}',
      );
      if (results is! List) return [];
      // saavnapi returns songs only — always map as Track
      return results
          .map((s) => _trackFromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Home feed ─────────────────────────────────────────────────────────────

  Future<List<CuratedPlaylist>> getHomeFeed() async {
    try {
      final results = await _api.get('/home');
      if (results is! List) return [];
      return results
          .map((s) => CuratedPlaylist.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<CuratedPlaylistData?> getCuratedPlaylist(String id) async {
    try {
      final result = await _api.get('/home/playlist/$id');
      return CuratedPlaylistData.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ─── Charts & moods ────────────────────────────────────────────────────────

  /// Fetch trending charts tracks.
  Future<List<Track>> getCharts() async {
    try {
      final results = await _api.get('/home/charts');
      if (results is! List) return [];
      return results
          .map((t) => _trackFromJson(t as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch mood/genre categories for the mood browsing grid.
  Future<List<MoodCategory>> getMoodCategories() async {
    try {
      final results = await _api.get('/home/moods');
      if (results is! List) return _fallbackMoodCategories();
      return results
          .map((c) => MoodCategory.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return _fallbackMoodCategories();
    }
  }

  /// Fetch tracks for a specific mood playlist.
  Future<CuratedPlaylistData?> getMoodPlaylist(String playlistId) async {
    try {
      final result = await _api.get('/home/mood/$playlistId');
      return CuratedPlaylistData.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ─── Artist ────────────────────────────────────────────────────────────────

  /// Fetch full artist details: bio, top songs, albums, singles, related artists.
  Future<Artist?> getArtist(String artistId) async {
    try {
      final result = await _api.get('/music/artist/$artistId');
      return Artist.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ─── Album ─────────────────────────────────────────────────────────────────

  /// Fetch full album details with track list.
  Future<Album?> getAlbum(String albumId) async {
    try {
      final result = await _api.get('/music/album/$albumId');
      return Album.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ─── Lyrics ────────────────────────────────────────────────────────────────

  /// Fetch lyrics for a track. Returns null if unavailable.
  Future<Lyrics?> getLyrics(String videoId) async {
    try {
      final result = await _api.get('/music/lyrics/$videoId');
      if (result == null) return null;
      return Lyrics.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ─── Watch playlist (radio / autoplay) ─────────────────────────────────────

  /// Get the YT Music "watch next" queue for a video — used to seed autoplay.
  Future<List<Track>> getWatchPlaylist(String videoId) async {
    try {
      final results = await _api.get('/music/watch/$videoId');
      if (results is! List) return [];
      return results
          .map((t) => _trackFromJson(t as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Stream URL ────────────────────────────────────────────────────────────

  /// Get the direct audio stream URL from the JioSaavn backend.
  /// Returns a stable MP4 CDN URL.
  Future<String> getAudioStreamUrl(String videoId) async {
    final res = await _api.get('/music/stream/$videoId');
    final url = res['streamUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Backend returned null streamUrl for $videoId');
    }
    return url;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Track _trackFromJson(Map<String, dynamic> json) {
    // Duration can come as milliseconds ('durationMs') or raw seconds/string ('duration')
    Duration dur;
    if (json.containsKey('durationMs')) {
      dur = Duration(milliseconds: (json['durationMs'] as num).toInt());
    } else if (json.containsKey('duration')) {
      final d = json['duration'];
      if (d is num) {
        dur = Duration(seconds: d.toInt());
      } else if (d is String) {
        // "3:45" format
        final parts = d.split(':');
        final mins = parts.length > 1 ? int.tryParse(parts[0]) ?? 0 : 0;
        final secs = int.tryParse(parts.last) ?? 0;
        dur = Duration(minutes: mins, seconds: secs);
      } else {
        dur = const Duration(seconds: 180);
      }
    } else {
      dur = const Duration(seconds: 180);
    }

    return Track(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      duration: dur,
      source: json['source'] as String?,
      streamUrl: json['streamUrl'] as String?,
      bitrate: (json['bitrate'] as num?)?.toInt(),
      artistId: json['artistId'] as String?,
      albumId: json['albumId'] as String?,
      albumTitle: json['albumTitle'] as String?,
    );
  }

  /// Hardcoded fallback mood categories when backend is unreachable.
  List<MoodCategory> _fallbackMoodCategories() {
    return [
      MoodCategory(
        title: 'Moods & Genres',
        playlists: [
          MoodPlaylist(
            title: 'Happy Hits',
            playlistId: 'top50india',
            thumbnailUrl: '',
            color1: const Color(0xFFFFAB40),
            color2: const Color(0xFFFF6D00),
          ),
          MoodPlaylist(
            title: 'Workout',
            playlistId: 'punjabihits',
            thumbnailUrl: '',
            color1: const Color(0xFFEF5350),
            color2: const Color(0xFFB71C1C),
          ),
          MoodPlaylist(
            title: 'Chill',
            playlistId: 'bollywoodhits',
            thumbnailUrl: '',
            color1: const Color(0xFF42A5F5),
            color2: const Color(0xFF1565C0),
          ),
          MoodPlaylist(
            title: 'Focus',
            playlistId: 'globaltop50',
            thumbnailUrl: '',
            color1: const Color(0xFF66BB6A),
            color2: const Color(0xFF2E7D32),
          ),
          MoodPlaylist(
            title: 'Bollywood',
            playlistId: 'bollywoodhits',
            thumbnailUrl: '',
            color1: const Color(0xFFAB47BC),
            color2: const Color(0xFF6A1B9A),
          ),
          MoodPlaylist(
            title: 'Trending',
            playlistId: 'top50india',
            thumbnailUrl: '',
            color1: const Color(0xFF26C6DA),
            color2: const Color(0xFF00838F),
          ),
        ],
      ),
    ];
  }

  void dispose() {}
}

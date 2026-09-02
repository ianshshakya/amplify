import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/lyrics.dart';
import '../models/mood_category.dart';
import 'api_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Central service for all music data fetching.
/// Talks to our Node.js backend which uses JioSaavn (saavnapi) for search
/// and direct MP4 stream URL delivery.
class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final ApiClient _api = ApiClient();

  // ─── Search ────────────────────────────────────────────────────────────────

  /// Search for songs using the backend API.
  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = await _api.get('/music/search?q=${Uri.encodeComponent(query)}');
      if (results is! List) return [];
      final tracks = results.map((v) => _trackFromJson(v as Map<String, dynamic>)).toList();
      
      // Filter out duplicate tracks (by title and artist)
      return Track.deduplicate(tracks);
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  /// Search with a specific filter type
  Future<List<dynamic>> searchWithFilter(String query, String type) async {
    try {
      final results = await _api.get('/music/search?q=${Uri.encodeComponent(query)}&type=$type');
      if (results is! List) return [];
      
      if (type == 'artists') {
        return results.map((v) => ArtistSummary.fromJson(v as Map<String, dynamic>)).toList();
      } else if (type == 'albums') {
        return results.map((v) => Album.fromJson(v as Map<String, dynamic>)).toList();
      } else {
        final tracks = results.map((v) => _trackFromJson(v as Map<String, dynamic>)).toList();
        return Track.deduplicate(tracks);
      }
    } catch (e) {
      debugPrint('Search error: $e');
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
      if (result == null) return null;
      return CuratedPlaylistData.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting curated playlist: $e');
      return null;
    }
  }

  // ─── Charts & moods ────────────────────────────────────────────────────────

  /// Fetch trending charts tracks locally.
  Future<List<Track>> getCharts() async {
    try {
      final results = await _api.get('/home/charts');
      if (results is! List) return [];
      return results
          .map((v) => _trackFromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting charts: $e');
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
    return getCuratedPlaylist(playlistId);
  }

  // ─── Artist ────────────────────────────────────────────────────────────────

  /// Fetch artist details using backend route.
  Future<Artist?> getArtist(String artistId) async {
    try {
      final result = await _api.get('/music/artist/${Uri.encodeComponent(artistId)}');
      if (result == null) return null;
      return Artist.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Fetch a specific page of an artist's songs.
  Future<List<Track>> getArtistSongs(String artistId, int page) async {
    try {
      final result = await _api.get('/music/artist/${Uri.encodeComponent(artistId)}/songs?page=$page');
      if (result == null) return [];
      return Track.deduplicate((result as List)
          .map((json) => Track.fromJson(json as Map<String, dynamic>))
          .toList());
    } catch (e) {
      return [];
    }
  }

  // ─── Album ─────────────────────────────────────────────────────────────────

  /// Fetch full album details using local search.
  Future<Album?> getAlbum(String albumId) async {
    try {
      final tracks = await search('$albumId full album');
      return Album(
        id: albumId,
        title: albumId,
        artistName: 'Unknown',
        year: '',
        thumbnailUrl: tracks.isNotEmpty ? tracks.first.thumbnailUrl : '',
        totalDuration: Duration.zero,
        tracks: tracks,
      );
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

  /// Get the "watch next" queue for a video from the backend.
  Future<List<Track>> getWatchPlaylist(String videoId) async {
    try {
      final results = await _api.get('/music/watch/$videoId');
      if (results is! List) return [];
      return results.map((v) => _trackFromJson(v as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Watch playlist error: $e');
      return [];
    }
  }

  /// Get the direct audio stream URL from the backend.
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final res = await _api.get('/music/stream/$videoId');
      if (res != null && res['streamUrl'] != null) {
        return res['streamUrl'];
      }
      throw Exception('Backend returned null streamUrl');
    } catch (e) {
      throw Exception('Failed to extract stream from backend for $videoId: $e');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  // ─── Telemetry ─────────────────────────────────────────────────────────────
  
  /// Dispatches a listening event to the backend's self-learning engine.
  Future<void> logListeningEvent(
    Track track, 
    String eventType, 
    {
      int? durationMs, 
      int? completionPercent, 
      String? context,
      String? sessionId
    }
  ) async {
    try {
      await _api.post('/analytics/events', body: {
        'song': {
          'videoId': track.videoId,
          'title': track.title,
          'artist': track.artist,
          'thumbnailUrl': track.thumbnailUrl,
          'durationMs': track.duration.inMilliseconds,
          'source': track.source
        },
        'eventType': eventType,
        'durationPlayedMs': durationMs ?? 0,
        'completionPercent': completionPercent ?? 0,
        'context': context,
        'sessionId': sessionId,
      });
    } catch (e) {
      debugPrint('Failed to log $eventType event: $e');
    }
  }

  // ─── Intelligent Recommendations ───────────────────────────────────────────

  Future<CuratedPlaylistData?> getDailyMix() async {
    try {
      final result = await _api.get('/recommendations/daily-mix');
      if (result == null || result['songs'] == null) return null;
      
      return CuratedPlaylistData(
        id: result['id'] ?? 'daily-mix',
        title: result['title'] ?? 'Daily Mix',
        description: result['description'] ?? 'Made for you',
        thumbnailUrl: result['thumbnailUrl'] ?? '',
        songs: (result['songs'] as List).map((v) => _trackFromJson(v as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      debugPrint('Daily Mix error: $e');
      return null;
    }
  }

  Future<Track?> getOneSongAway() async {
    try {
      final result = await _api.get('/recommendations/one-song-away');
      if (result == null) return null;
      return _trackFromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('One Song Away error: $e');
      return null;
    }
  }

  Future<List<Track>> getSongRadio(String songId) async {
    try {
      final results = await _api.get('/recommendations/radio/song/$songId');
      if (results is! List) return [];
      return results.map((v) => _trackFromJson(v as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Song Radio error: $e');
      return [];
    }
  }

  Future<List<Track>> getArtistRadio(String artistName) async {
    try {
      final results = await _api.get('/recommendations/radio/artist/${Uri.encodeComponent(artistName)}');
      if (results is! List) return [];
      return results.map((v) => _trackFromJson(v as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Artist Radio error: $e');
      return [];
    }
  }

  /// Get the next batch of autoplay tracks using session context for smarter radio.
  Future<List<Track>> getNextTracks(Track currentSong, dynamic sessionCtx) async {
    try {
      final sessionHistory = sessionCtx?.recentSongIds ?? <String>[];
      final sessionArtists = sessionCtx?.recentArtists ?? <String>[];

      final results = await _api.post('/recommendations/next', body: {
        'currentSong': {
          'videoId': currentSong.videoId,
          'title': currentSong.title,
          'artist': currentSong.artist,
          'thumbnailUrl': currentSong.thumbnailUrl,
          'durationMs': currentSong.duration.inMilliseconds,
          'source': currentSong.source,
        },
        'sessionHistory': sessionHistory,
        'sessionArtists': sessionArtists,
        // Pass mood/energy overrides from voice commands if present
        if (sessionCtx?.currentMood != null) 'mood': sessionCtx!.currentMood,
        if (sessionCtx?.currentEnergy != null) 'energy': sessionCtx!.currentEnergy,
      });

      if (results is! List) return [];
      return results.map((v) => _trackFromJson(v as Map<String, dynamic>)).toList();
    } catch (e) {
      // Fallback to basic song radio
      debugPrint('getNextTracks error: $e — falling back to song radio');
      return getSongRadio(currentSong.videoId);
    }
  }

  /// Generate a dynamic playlist based on a natural language intent (e.g. "smooth", "energetic workout").
  Future<List<Track>> generatePlaylist(String intent) async {
    try {
      final result = await _api.post('/recommendations/playlist', body: {
        'intent': intent,
        'targetCount': 20,
      });
      if (result != null && result['songs'] is List) {
        return (result['songs'] as List).map((v) => _trackFromJson(v as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('generatePlaylist error: $e');
      return [];
    }
  }

  /// Parse a raw voice text string into a structured command via the backend NLP.
  /// Used by Level 2 of VoiceCommandParser for ambiguous natural-language requests.
  Future<Map<String, dynamic>?> parseVoiceIntent({
    required String text,
    String? currentSong,
    String? currentArtist,
    List<String> sessionHistory = const [],
    List<String> sessionArtists = const [],
  }) async {
    try {
      final result = await _api.post('/recommendations/voice-intent', body: {
        'text': text,
        'currentSong': currentSong,
        'currentArtist': currentArtist,
        'sessionHistory': sessionHistory,
        'sessionArtists': sessionArtists,
      });
      return result as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('parseVoiceIntent error: $e');
      return null;
    }
  }

  /// Get tracks similar to a given song.
  Future<List<Track>> getSimilarTracks(Track song) async {
    try {
      final results = await _api.post('/recommendations/similar', body: {
        'song': {
          'videoId': song.videoId,
          'title': song.title,
          'artist': song.artist,
          'thumbnailUrl': song.thumbnailUrl,
          'durationMs': song.duration.inMilliseconds,
          'source': song.source,
        },
      });
      if (results is! List) return [];
      return Track.deduplicate((results as List)
          .map((v) => _trackFromJson(v as Map<String, dynamic>))
          .toList());
    } catch (e) {
      debugPrint('getSimilarTracks error: $e');
      return [];
    }
  }

  // ─── JSON Parsing ──────────────────────────────────────────────────────────

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

    // Normalize the source so the rest of the application doesn't have to care
    final source = json['source'] as String? ?? 
        ((json['videoId'] as String? ?? '').startsWith('creator_') ? 'archive' : 'saavn');

    return Track(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      duration: dur,
      source: source,
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

}

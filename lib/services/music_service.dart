import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/lyrics.dart';
import '../models/mood_category.dart';
import 'api_client.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
  final YoutubeExplode _yt = YoutubeExplode();

  // ─── Search ────────────────────────────────────────────────────────────────

  /// Search YouTube for songs using local youtube_explode_dart.
  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = await _yt.search.search(query);
      return results.map((v) => Track(
        videoId: v.id.value,
        title: v.title,
        artist: v.author,
        thumbnailUrl: v.thumbnails.highResUrl,
        duration: v.duration ?? const Duration(minutes: 3),
      )).toList();
    } catch (e) {
      debugPrint('Local search error: $e');
      return [];
    }
  }

  /// Search with a specific filter type
  Future<List<dynamic>> searchWithFilter(String query, String type) async {
    // For now, we only support songs via YoutubeExplode
    return search(query);
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
      final results = await getHomeFeed();
      final p = results.firstWhere((p) => p.id == id);
      
      final songs = await search(p.query);
      return CuratedPlaylistData(
        id: p.id,
        title: p.title,
        description: p.description,
        thumbnailUrl: songs.isNotEmpty ? songs.first.thumbnailUrl : '',
        songs: songs,
      );
    } catch (e) {
      return null;
    }
  }

  // ─── Charts & moods ────────────────────────────────────────────────────────

  /// Fetch trending charts tracks locally.
  Future<List<Track>> getCharts() async {
    return search('Top global hits 2024');
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

  /// Fetch tracks for a specific mood playlist locally.
  Future<CuratedPlaylistData?> getMoodPlaylist(String playlistId) async {
    try {
      final songs = await search('$playlistId music');
      return CuratedPlaylistData(
        id: playlistId,
        title: playlistId,
        description: 'Mood playlist',
        thumbnailUrl: songs.isNotEmpty ? songs.first.thumbnailUrl : '',
        songs: songs,
      );
    } catch (e) {
      return null;
    }
  }

  // ─── Artist ────────────────────────────────────────────────────────────────

  /// Fetch artist details using local search.
  Future<Artist?> getArtist(String artistId) async {
    try {
      final tracks = await search('$artistId songs');
      return Artist(
        id: artistId,
        name: artistId,
        thumbnailUrl: tracks.isNotEmpty ? tracks.first.thumbnailUrl : '',
        subscribers: 'Unknown',
        description: '',
        topSongs: tracks,
        albums: [],
        singles: [],
        relatedArtists: [],
      );
    } catch (e) {
      return null;
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

  /// Get the YT Music "watch next" queue for a video using local YoutubeExplode.
  Future<List<Track>> getWatchPlaylist(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      final related = await _yt.videos.getRelatedVideos(video);
      if (related == null) return [];
      return related.map((v) => Track(
        videoId: v.id.value,
        title: v.title,
        artist: v.author,
        thumbnailUrl: v.thumbnails.highResUrl,
        duration: v.duration ?? const Duration(minutes: 3),
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get the direct audio stream URL using Piped APIs exclusively to prevent 403 Forbidden.
  /// Get the direct audio stream URL using youtube_explode_dart locally.
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        return audioStreams.withHighestBitrate().url.toString();
      }
      
      final muxedStreams = manifest.muxed;
      if (muxedStreams.isNotEmpty) {
        return muxedStreams.withHighestBitrate().url.toString();
      }
      
      throw Exception('No streams found for $videoId');
    } catch (e) {
      throw Exception('Failed to extract stream locally for $videoId: $e');
    }
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

  void dispose() {
    _yt.close();
  }
}

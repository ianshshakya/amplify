import 'package:flutter/material.dart';

/// A top-level mood/genre category as returned by YT Music's mood categories endpoint.
class MoodCategory {
  final String title;
  final List<MoodPlaylist> playlists;

  const MoodCategory({
    required this.title,
    required this.playlists,
  });

  factory MoodCategory.fromJson(Map<String, dynamic> json) => MoodCategory(
        title: json['title'] as String? ?? '',
        playlists: (json['playlists'] as List<dynamic>? ?? [])
            .map((p) => MoodPlaylist.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// A single mood/genre playlist tile (e.g. "Happy Hits", "Workout Anthems").
class MoodPlaylist {
  final String title;
  final String playlistId;
  final String thumbnailUrl;
  /// Gradient color pair for the tile background (nullable, we derive from thumbnail otherwise).
  final Color? color1;
  final Color? color2;

  const MoodPlaylist({
    required this.title,
    required this.playlistId,
    required this.thumbnailUrl,
    this.color1,
    this.color2,
  });

  factory MoodPlaylist.fromJson(Map<String, dynamic> json) {
    Color? parseColor(dynamic hex) {
      if (hex == null) return null;
      final s = hex.toString().replaceFirst('#', '');
      final val = int.tryParse(s, radix: 16);
      return val == null ? null : Color(0xFF000000 | val);
    }

    return MoodPlaylist(
      title: json['title'] as String? ?? '',
      playlistId: json['playlistId'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      color1: parseColor(json['color1']),
      color2: parseColor(json['color2']),
    );
  }
}

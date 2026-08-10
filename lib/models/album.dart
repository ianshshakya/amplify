import 'track.dart';

/// Represents a music album fetched from YT Music.
class Album {
  final String id;
  final String title;
  final String artistName;
  final String artistId;
  final String thumbnailUrl;
  final String? year;
  final List<Track> tracks;
  final Duration totalDuration;

  const Album({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId = '',
    required this.thumbnailUrl,
    this.year,
    this.tracks = const [],
    this.totalDuration = Duration.zero,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'] as List<dynamic>? ?? [];
    final tracks = rawTracks
        .map((t) => Track.fromJson(t as Map<String, dynamic>))
        .toList();

    final totalMs = tracks.fold<int>(
        0, (sum, t) => sum + t.duration.inMilliseconds);

    return Album(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Album',
      artistName: json['artistName'] as String? ?? 'Unknown Artist',
      artistId: json['artistId'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      year: json['year']?.toString(),
      tracks: tracks,
      totalDuration: Duration(milliseconds: totalMs),
    );
  }

  /// Lightweight version used in artist page/search results (no full track list).
  factory Album.fromSummaryJson(Map<String, dynamic> json) => Album(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown Album',
        artistName: json['artistName'] as String? ?? '',
        artistId: json['artistId'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        year: json['year']?.toString(),
      );
}

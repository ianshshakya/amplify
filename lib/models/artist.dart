import 'track.dart';
import 'album.dart';

/// Represents an artist fetched from YT Music via the backend.
class Artist {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String description;
  final String subscribers;
  final List<Track> topSongs;
  final List<Album> albums;
  final List<Album> singles;
  final List<ArtistSummary> relatedArtists;

  const Artist({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    this.description = '',
    this.subscribers = '',
    this.topSongs = const [],
    this.albums = const [],
    this.singles = const [],
    this.relatedArtists = const [],
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Artist',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
      subscribers: json['subscribers'] as String? ?? '',
      topSongs: (json['topSongs'] as List<dynamic>? ?? [])
          .map((t) => Track.fromJson(t as Map<String, dynamic>))
          .toList(),
      albums: (json['albums'] as List<dynamic>? ?? [])
          .map((a) => Album.fromJson(a as Map<String, dynamic>))
          .toList(),
      singles: (json['singles'] as List<dynamic>? ?? [])
          .map((a) => Album.fromJson(a as Map<String, dynamic>))
          .toList(),
      relatedArtists: (json['relatedArtists'] as List<dynamic>? ?? [])
          .map((a) => ArtistSummary.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Lightweight artist reference used in search results and related-artists rows.
class ArtistSummary {
  final String id;
  final String name;
  final String thumbnailUrl;

  const ArtistSummary({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
  });

  factory ArtistSummary.fromJson(Map<String, dynamic> json) => ArtistSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown Artist',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      );
}

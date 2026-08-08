import 'track.dart';

/// Server-side playlist shape — note `id` comes from Mongo's `_id`,
/// unlike the old Hive-based Playlist model.
class ApiPlaylist {
  final String id;
  final String name;
  final List<Track> tracks;

  ApiPlaylist({required this.id, required this.name, required this.tracks});

  factory ApiPlaylist.fromJson(Map<String, dynamic> json) => ApiPlaylist(
        id: json['_id'] as String,
        name: json['name'] as String,
        tracks: (json['tracks'] as List)
            .map((t) => Track.fromJson(_normalizeTrackJson(t)))
            .toList(),
      );

  // Backend stores duration as `durationMs`; our Track.fromJson expects
  // `durationMs` too, so this just guards against key mismatches if the
  // API shape ever shifts slightly.
  static Map<String, dynamic> _normalizeTrackJson(Map<String, dynamic> json) => json;
}

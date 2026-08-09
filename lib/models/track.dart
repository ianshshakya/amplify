/// Represents a single playable track sourced from YouTube.
/// Used across search results, playlists, and the now-playing player.
class Track {
  final String videoId;
  final String title;
  final String artist; // channel name, used as "artist"
  final String thumbnailUrl;
  final Duration duration;

  Track({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'durationMs': duration.inMilliseconds,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        videoId: json['videoId'],
        title: json['title'],
        artist: json['artist'],
        thumbnailUrl: json['thumbnailUrl'],
        duration: Duration(milliseconds: json['durationMs']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Track && other.videoId == videoId);

  @override
  int get hashCode => videoId.hashCode;
}

class HomeSection {
  final String title;
  final List<Track> songs;

  HomeSection({required this.title, required this.songs});

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      title: json['title'] as String,
      songs: (json['songs'] as List).map((t) => Track(
        videoId: t['videoId'] as String,
        title: t['title'] as String,
        artist: t['artist'] as String,
        thumbnailUrl: t['thumbnailUrl'] as String,
        duration: const Duration(seconds: 180),
      )).toList(),
    );
  }
}

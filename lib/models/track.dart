/// Represents a single playable track sourced from YouTube Music.
/// Used across search results, playlists, artist pages, and the now-playing player.
class Track {
  final String videoId;
  final String title;
  final String artist; 
  final String thumbnailUrl;
  final Duration duration;

  // New unified source fields
  final String? source;
  final String? streamUrl;
  final int? bitrate;

  // Optional enrichment fields (populated in artist/album detail views)
  final String? artistId;
  final String? albumId;
  final String? albumTitle;
  final int? trackNumber;

  const Track({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.duration,
    this.source,
    this.streamUrl,
    this.bitrate,
    this.artistId,
    this.albumId,
    this.albumTitle,
    this.trackNumber,
  });

  Track copyWith({
    String? videoId,
    String? title,
    String? artist,
    String? thumbnailUrl,
    Duration? duration,
    String? source,
    String? streamUrl,
    int? bitrate,
    String? artistId,
    String? albumId,
    String? albumTitle,
    int? trackNumber,
  }) =>
      Track(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        duration: duration ?? this.duration,
        source: source ?? this.source,
        streamUrl: streamUrl ?? this.streamUrl,
        bitrate: bitrate ?? this.bitrate,
        artistId: artistId ?? this.artistId,
        albumId: albumId ?? this.albumId,
        albumTitle: albumTitle ?? this.albumTitle,
        trackNumber: trackNumber ?? this.trackNumber,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'durationMs': duration.inMilliseconds,
        if (source != null) 'source': source,
        if (streamUrl != null) 'streamUrl': streamUrl,
        if (bitrate != null) 'bitrate': bitrate,
        if (artistId != null) 'artistId': artistId,
        if (albumId != null) 'albumId': albumId,
        if (albumTitle != null) 'albumTitle': albumTitle,
        if (trackNumber != null) 'trackNumber': trackNumber,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        videoId: json['videoId'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
        source: json['source'] as String?,
        streamUrl: json['streamUrl'] as String?,
        bitrate: (json['bitrate'] as num?)?.toInt(),
        artistId: json['artistId'] as String?,
        albumId: json['albumId'] as String?,
        albumTitle: json['albumTitle'] as String?,
        trackNumber: (json['trackNumber'] as num?)?.toInt(),
      );

  /// Filters out duplicate tracks that have the same title and artist
  static List<Track> deduplicate(List<Track> tracks) {
    final unique = <String, Track>{};
    for (final t in tracks) {
      final key = '${t.title.trim().toLowerCase()}_${t.artist.trim().toLowerCase()}';
      if (!unique.containsKey(key)) {
        unique[key] = t;
      }
    }
    return unique.values.toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Track && other.videoId == videoId);

  @override
  int get hashCode => videoId.hashCode;
}

// ─── Curated Playlist models (home feed) ────────────────────────────────────

class CuratedPlaylist {
  final String id;
  final String title;
  final String type;
  final String thumbnailUrl;
  final String description;
  final String query;

  const CuratedPlaylist({
    required this.id,
    required this.title,
    this.type = 'Mixes For You',
    required this.thumbnailUrl,
    required this.description,
    this.query = '',
  });

  factory CuratedPlaylist.fromJson(Map<String, dynamic> json) =>
      CuratedPlaylist(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? 'Mixes For You',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        query: json['query'] as String? ?? '',
      );
}

class CuratedPlaylistData extends CuratedPlaylist {
  final List<Track> songs;

  const CuratedPlaylistData({
    required super.id,
    required super.title,
    super.type = 'Mixes For You',
    required super.thumbnailUrl,
    required super.description,
    required this.songs,
  });

  factory CuratedPlaylistData.fromJson(Map<String, dynamic> json) =>
      CuratedPlaylistData(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? 'Mixes For You',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        songs: (json['songs'] as List<dynamic>? ?? [])
            .map((t) => Track.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

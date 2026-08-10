/// Represents a podcast show on YT Music.
class Podcast {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String description;
  final List<PodcastEpisode> episodes;

  const Podcast({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.description = '',
    this.episodes = const [],
  });

  factory Podcast.fromJson(Map<String, dynamic> json) => Podcast(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        episodes: (json['episodes'] as List<dynamic>? ?? [])
            .map((e) => PodcastEpisode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A single episode from a podcast. Shares the same videoId mechanism as a Track.
class PodcastEpisode {
  final String videoId;
  final String title;
  final String podcastTitle;
  final String thumbnailUrl;
  final Duration duration;
  final String? publishedDate;
  final String? description;

  const PodcastEpisode({
    required this.videoId,
    required this.title,
    required this.podcastTitle,
    required this.thumbnailUrl,
    required this.duration,
    this.publishedDate,
    this.description,
  });

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) => PodcastEpisode(
        videoId: json['videoId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        podcastTitle: json['podcastTitle'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        duration: Duration(
          seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        ),
        publishedDate: json['publishedDate'] as String?,
        description: json['description'] as String?,
      );
}

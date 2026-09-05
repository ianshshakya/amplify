import 'track.dart';

class HomeFeed {
  final String greeting;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final List<HomeFeedSection> sections;

  const HomeFeed({required this.greeting, required this.generatedAt, required this.expiresAt, required this.sections});

  factory HomeFeed.fromJson(Map<String, dynamic> json) => HomeFeed(
        greeting: json['greeting'] as String? ?? 'Welcome back',
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now(),
        sections: (json['sections'] as List? ?? [])
            .whereType<Map>()
            .map((item) => HomeFeedSection.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class HomeFeedSection {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String reason;
  final int priority;
  final List<HomeFeedItem> items;

  const HomeFeedSection({required this.id, required this.type, required this.title, required this.subtitle, required this.reason, required this.priority, required this.items});

  factory HomeFeedSection.fromJson(Map<String, dynamic> json) => HomeFeedSection(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'PLAYLIST',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List? ?? [])
            .whereType<Map>()
            .map((item) => HomeFeedItem.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class HomeFeedItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Track? track;
  final Map<String, dynamic> metadata;

  const HomeFeedItem({required this.id, required this.type, required this.title, required this.subtitle, required this.imageUrl, this.track, this.metadata = const {}});

  factory HomeFeedItem.fromJson(Map<String, dynamic> json) => HomeFeedItem(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'PLAYLIST',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        track: json['track'] is Map ? Track.fromJson(Map<String, dynamic>.from(json['track'] as Map)) : null,
        metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : const {},
      );
}

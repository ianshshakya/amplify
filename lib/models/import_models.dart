// lib/models/import_models.dart
// Flutter-side data models for the Universal Music Import system.

enum ImportProvider { spotify, youtube }

extension ImportProviderName on ImportProvider {
  String get displayName {
    switch (this) {
      case ImportProvider.spotify:  return 'Spotify';
      case ImportProvider.youtube:  return 'YouTube Music';
    }
  }

  String get id {
    switch (this) {
      case ImportProvider.spotify:  return 'spotify';
      case ImportProvider.youtube:  return 'youtube';
    }
  }

  static ImportProvider fromId(String id) {
    switch (id) {
      case 'spotify':  return ImportProvider.spotify;
      case 'youtube':  return ImportProvider.youtube;
      default:         return ImportProvider.spotify;
    }
  }
}

// ─── Import Job ─────────────────────────────────────────────────────────────

enum ImportStatus {
  queued, authorizing, fetching, matching, importing,
  processingHistory, completed, partial, failed, cancelled,
}

extension ImportStatusExt on ImportStatus {
  static ImportStatus fromString(String s) {
    switch (s.toUpperCase()) {
      case 'QUEUED':             return ImportStatus.queued;
      case 'AUTHORIZING':        return ImportStatus.authorizing;
      case 'FETCHING':           return ImportStatus.fetching;
      case 'MATCHING':           return ImportStatus.matching;
      case 'IMPORTING':          return ImportStatus.importing;
      case 'PROCESSING_HISTORY': return ImportStatus.processingHistory;
      case 'COMPLETED':          return ImportStatus.completed;
      case 'PARTIAL':            return ImportStatus.partial;
      case 'FAILED':             return ImportStatus.failed;
      case 'CANCELLED':          return ImportStatus.cancelled;
      default:                   return ImportStatus.queued;
    }
  }

  String get label {
    switch (this) {
      case ImportStatus.queued:             return 'Queued';
      case ImportStatus.authorizing:        return 'Connecting…';
      case ImportStatus.fetching:           return 'Fetching library…';
      case ImportStatus.matching:           return 'Matching tracks…';
      case ImportStatus.importing:          return 'Importing playlists…';
      case ImportStatus.processingHistory:  return 'Processing history…';
      case ImportStatus.completed:          return 'Complete';
      case ImportStatus.partial:            return 'Partially complete';
      case ImportStatus.failed:             return 'Failed';
      case ImportStatus.cancelled:          return 'Cancelled';
    }
  }

  bool get isActive =>
    this == ImportStatus.queued ||
    this == ImportStatus.authorizing ||
    this == ImportStatus.fetching ||
    this == ImportStatus.matching ||
    this == ImportStatus.importing ||
    this == ImportStatus.processingHistory;

  bool get isFinished =>
    this == ImportStatus.completed ||
    this == ImportStatus.partial ||
    this == ImportStatus.failed ||
    this == ImportStatus.cancelled;
}

class ImportJob {
  final String id;
  final String provider;
  final ImportStatus status;
  final int totalItems;
  final int processedItems;
  final int matchedItems;
  final int reviewItems;
  final int unavailableItems;
  final int playlistsImported;
  final int historyRecords;
  final String? error;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ImportJob({
    required this.id,
    required this.provider,
    required this.status,
    required this.totalItems,
    required this.processedItems,
    required this.matchedItems,
    required this.reviewItems,
    required this.unavailableItems,
    required this.playlistsImported,
    required this.historyRecords,
    this.error,
    required this.startedAt,
    this.completedAt,
  });

  double get progress =>
    totalItems > 0 ? processedItems / totalItems : 0.0;

  factory ImportJob.fromJson(Map<String, dynamic> json) => ImportJob(
    id:                json['_id'] as String? ?? json['id'] as String? ?? '',
    provider:          json['provider'] as String? ?? '',
    status:            ImportStatusExt.fromString(json['status'] as String? ?? 'QUEUED'),
    totalItems:        (json['totalItems'] as num?)?.toInt() ?? 0,
    processedItems:    (json['processedItems'] as num?)?.toInt() ?? 0,
    matchedItems:      (json['matchedItems'] as num?)?.toInt() ?? 0,
    reviewItems:       (json['reviewItems'] as num?)?.toInt() ?? 0,
    unavailableItems:  (json['unavailableItems'] as num?)?.toInt() ?? 0,
    playlistsImported: (json['playlistsImported'] as num?)?.toInt() ?? 0,
    historyRecords:    (json['historyRecords'] as num?)?.toInt() ?? 0,
    error:             json['error'] as String?,
    startedAt:         DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
    completedAt:       json['completedAt'] != null
      ? DateTime.tryParse(json['completedAt'] as String)
      : null,
  );
}

// ─── Review Track ────────────────────────────────────────────────────────────

class ImportReviewTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? thumbnailUrl;
  final int? durationMs;
  final String matchStatus;
  final int confidenceScore;
  final List<ReviewCandidate> reviewCandidates;

  const ImportReviewTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.thumbnailUrl,
    this.durationMs,
    required this.matchStatus,
    required this.confidenceScore,
    required this.reviewCandidates,
  });

  factory ImportReviewTrack.fromJson(Map<String, dynamic> json) => ImportReviewTrack(
    id:                json['_id'] as String? ?? '',
    title:             json['title'] as String? ?? 'Unknown',
    artist:            json['artist'] as String? ?? 'Unknown',
    album:             json['album'] as String?,
    thumbnailUrl:      json['thumbnailUrl'] as String?,
    durationMs:        (json['durationMs'] as num?)?.toInt(),
    matchStatus:       json['matchStatus'] as String? ?? 'UNAVAILABLE',
    confidenceScore:   (json['confidenceScore'] as num?)?.toInt() ?? 0,
    reviewCandidates:  (json['reviewCandidates'] as List<dynamic>? ?? [])
        .map((c) => ReviewCandidate.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class ReviewCandidate {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int? durationMs;
  final int confidenceScore;

  const ReviewCandidate({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.durationMs,
    required this.confidenceScore,
  });

  factory ReviewCandidate.fromJson(Map<String, dynamic> json) => ReviewCandidate(
    videoId:         json['videoId'] as String? ?? '',
    title:           json['title'] as String? ?? 'Unknown',
    artist:          json['artist'] as String? ?? 'Unknown',
    thumbnailUrl:    json['thumbnailUrl'] as String?,
    durationMs:      (json['durationMs'] as num?)?.toInt(),
    confidenceScore: (json['confidenceScore'] as num?)?.toInt() ?? 0,
  );
}

// ─── Connected Service ────────────────────────────────────────────────────────

class ConnectedService {
  final String provider;
  final String? displayName;
  final DateTime connectedAt;
  final DateTime? expiresAt;

  const ConnectedService({
    required this.provider,
    this.displayName,
    required this.connectedAt,
    this.expiresAt,
  });

  factory ConnectedService.fromJson(Map<String, dynamic> json) => ConnectedService(
    provider:     json['provider'] as String? ?? '',
    displayName:  json['displayName'] as String?,
    connectedAt:  DateTime.tryParse(json['connectedAt'] as String? ?? '') ?? DateTime.now(),
    expiresAt:    json['expiresAt'] != null
      ? DateTime.tryParse(json['expiresAt'] as String)
      : null,
  );
}

// ─── Provider Info ────────────────────────────────────────────────────────────

class ProviderInfo {
  final String id;
  final String name;
  final String description;
  final bool configured;
  final String? limitation;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.configured,
    this.limitation,
  });

  factory ProviderInfo.fromJson(Map<String, dynamic> json) => ProviderInfo(
    id:          json['id'] as String? ?? '',
    name:        json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    configured:  json['configured'] as bool? ?? false,
    limitation:  json['limitation'] as String?,
  );
}

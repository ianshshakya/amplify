/// Represents lyrics for a track. Can be synced (with timestamps) or plain text.
class Lyrics {
  /// If non-null, each line has a start time in milliseconds for auto-scroll sync.
  final List<LyricLine>? syncedLines;

  /// Plain-text fallback (used if synced lines are not available).
  final String? plainText;

  const Lyrics({this.syncedLines, this.plainText});

  bool get hasSynced => syncedLines != null && syncedLines!.isNotEmpty;
  bool get hasContent => hasSynced || (plainText != null && plainText!.isNotEmpty);

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    final rawLines = json['syncedLines'] as List<dynamic>?;
    final synced = rawLines
        ?.map((l) => LyricLine.fromJson(l as Map<String, dynamic>))
        .toList();
    final rawText = (json['plainText'] ?? json['text']) as String?;
    final cleanedText = rawText?.split('\n').map((e) => e.trim()).join('\n');

    return Lyrics(
      syncedLines: synced,
      plainText: cleanedText,
    );
  }
}

/// A single line of synced lyric with a millisecond start timestamp.
class LyricLine {
  final int startTimeMs;
  final String text;

  const LyricLine({required this.startTimeMs, required this.text});

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        startTimeMs: (json['startTimeMs'] as num?)?.toInt() ?? 0,
        text: (json['text'] as String? ?? '').trim(),
      );
}

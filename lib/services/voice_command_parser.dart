import 'package:flutter/foundation.dart';
import '../models/voice_command.dart';
import '../services/api_client.dart';

/// Two-level voice command parser.
///
/// Level 1 — Deterministic: matches obvious commands via regex/keywords.
///   Covers: play, pause, stop, next, previous, volume up/down/set, open screens.
///   No network call. Instant.
///
/// Level 2 — Backend NLP: sends ambiguous text to /api/recommendations/voice-intent
///   which runs PlaylistIntentEngine (rule-based archetype matching).
///   Returns a structured VoiceCommand JSON. No LLM cost.
class VoiceCommandParser {
  static final VoiceCommandParser _instance = VoiceCommandParser._internal();
  factory VoiceCommandParser() => _instance;
  VoiceCommandParser._internal();

  final ApiClient _api = ApiClient();

  // ─── Public ────────────────────────────────────────────────────────────────

  /// Parse the recognized [text] into a structured [VoiceCommand].
  /// Always attempts Level 1 first. Falls back to Level 2 only when needed.
  Future<VoiceCommand> parse(
    String text, {
    String? currentSongTitle,
    String? currentArtist,
    List<String> sessionHistory = const [],
    List<String> sessionArtists = const [],
  }) async {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return VoiceCommand.unknown(text);

    // ── Level 1: deterministic ──
    final deterministic = _tryDeterministic(normalized);
    if (deterministic != null) return deterministic;

    // ── Level 2: backend NLP ──
    return _tryBackendIntent(
      text,
      currentSongTitle: currentSongTitle,
      currentArtist: currentArtist,
      sessionHistory: sessionHistory,
      sessionArtists: sessionArtists,
    );
  }

  // ─── Level 1 ───────────────────────────────────────────────────────────────

  VoiceCommand? _tryDeterministic(String text) {
    // --- Playback controls ---
    if (_matches(text, ['pause', 'stop music', 'stop the music', 'stop playing'])) {
      return const VoiceCommand(intent: VoiceIntent.pause, explanation: 'Pausing');
    }
    if (_matches(text, ['play', 'resume', 'continue', 'unpause', 'start'])) {
      // "play X" has a query, don't catch it here
      if (_isSimpleCommand(text)) {
        return const VoiceCommand(intent: VoiceIntent.play, explanation: 'Resuming');
      }
    }
    if (_matches(text, ['next', 'next song', 'skip', 'skip this', 'next track', 'forward'])) {
      return const VoiceCommand(intent: VoiceIntent.next, explanation: 'Skipping to next');
    }
    if (_matches(text, ['previous', 'go back', 'back', 'prev', 'last song', 'previous song', 'previous track'])) {
      return const VoiceCommand(intent: VoiceIntent.previous, explanation: 'Going to previous');
    }

    // --- Volume ---
    final volumeSet = _extractSetVolume(text);
    if (volumeSet != null) return volumeSet;
    if (_matches(text, ['volume up', 'louder', 'increase volume', 'turn it up', 'turn up'])) {
      return const VoiceCommand(intent: VoiceIntent.volumeUp, explanation: 'Increasing volume');
    }
    if (_matches(text, ['volume down', 'quieter', 'decrease volume', 'turn it down', 'turn down', 'lower volume'])) {
      return const VoiceCommand(intent: VoiceIntent.volumeDown, explanation: 'Decreasing volume');
    }

    // --- Navigation ---
    if (_matches(text, ['open search', 'go to search', 'search screen'])) {
      return const VoiceCommand(intent: VoiceIntent.openSearch, explanation: 'Opening Search');
    }
    if (_matches(text, ['liked songs', 'my likes', 'open liked', 'favorites', 'favourites'])) {
      return const VoiceCommand(intent: VoiceIntent.openLikedSongs, explanation: 'Opening Liked Songs');
    }
    if (_matches(text, ['playlists', 'my playlists', 'open playlists', 'library'])) {
      return const VoiceCommand(intent: VoiceIntent.openPlaylists, explanation: 'Opening Playlists');
    }

    // --- Queue ---
    if (_matches(text, ['clear queue', 'empty queue', 'clear playlist'])) {
      return const VoiceCommand(intent: VoiceIntent.clearQueue, explanation: 'Clearing queue');
    }
    if (_matchesAny(text, ['add to queue', 'queue this', 'add this to queue', 'play next'])) {
      return const VoiceCommand(intent: VoiceIntent.addToQueue, explanation: 'Added to queue');
    }

    // --- "Play [song/artist]" — direct search ---
    final playQuery = _extractPlayQuery(text);
    if (playQuery != null) {
      return VoiceCommand(
        intent: VoiceIntent.searchAndPlay,
        query: playQuery,
        explanation: 'Searching for "$playQuery"',
      );
    }

    // Not deterministic — go to Level 2
    return null;
  }

  // ─── Level 2 ───────────────────────────────────────────────────────────────

  Future<VoiceCommand> _tryBackendIntent(
    String text, {
    String? currentSongTitle,
    String? currentArtist,
    List<String> sessionHistory = const [],
    List<String> sessionArtists = const [],
  }) async {
    try {
      final result = await _api.post('/recommendations/voice-intent', body: {
        'text': text,
        'currentSong': currentSongTitle,
        'currentArtist': currentArtist,
        'sessionHistory': sessionHistory,
        'sessionArtists': sessionArtists,
      });

      if (result == null || result is! Map<String, dynamic>) {
        return VoiceCommand.unknown(text);
      }

      final cmd = VoiceCommand.fromJson(result);
      // Validate — never trust unknown intents from the backend
      if (cmd.intent == VoiceIntent.unknown) return VoiceCommand.unknown(text);
      return cmd;
    } catch (e) {
      debugPrint('[VoiceCommandParser] Backend NLP failed: $e');
      return VoiceCommand.unknown(text);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  bool _matches(String text, List<String> patterns) =>
      patterns.any((p) => text == p);

  bool _matchesAny(String text, List<String> patterns) =>
      patterns.any((p) => text.contains(p));

  /// True if the text is just a bare command with no trailing query
  bool _isSimpleCommand(String text) =>
      text.split(' ').length <= 2 && !text.contains(RegExp(r'[a-z]{5,}', caseSensitive: false));

  /// "play something" and "play [song]" disambiguation:
  /// Returns query only if "play" is followed by actual content that isn't a mood keyword.
  String? _extractPlayQuery(String text) {
    const moodWords = {'something', 'some', 'a', 'me', 'music', 'songs', 'song'};
    const prefixes = ['play ', 'search for ', 'find '];
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        final rest = text.substring(prefix.length).trim();
        if (rest.isNotEmpty) {
          final firstWord = rest.split(' ').first;
          // If the first word is a mood-y filler, let Level 2 handle it
          if (moodWords.contains(firstWord)) return null;
          return rest;
        }
      }
    }
    return null;
  }

  /// Extracts "set volume to X percent" → VoiceCommand with volumePercent set.
  VoiceCommand? _extractSetVolume(String text) {
    final pattern = RegExp(r'(?:set volume|volume) (?:to )?(\d+)(?:\s*%| percent)?');
    final match = pattern.firstMatch(text);
    if (match != null) {
      final percent = int.tryParse(match.group(1) ?? '');
      if (percent != null) {
        final clamped = percent.clamp(0, 100);
        return VoiceCommand(
          intent: VoiceIntent.setVolume,
          volumePercent: clamped,
          explanation: 'Setting volume to $clamped%',
        );
      }
    }
    return null;
  }
}

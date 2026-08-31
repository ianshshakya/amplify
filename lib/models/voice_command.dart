/// Represents the structured intent extracted from a voice command.
enum VoiceIntent {
  play,           // Resume playback
  pause,          // Pause playback
  stop,           // Stop playback
  next,           // Skip to next
  previous,       // Go to previous
  searchAndPlay,  // Search for a song/artist and play it
  addToQueue,     // Add current or searched song to queue
  clearQueue,     // Clear the current queue
  volumeUp,       // Increase volume
  volumeDown,     // Decrease volume
  setVolume,      // Set volume to a specific percent
  openSearch,     // Navigate to the search screen
  openLikedSongs, // Navigate to liked songs
  openPlaylists,  // Navigate to playlists
  recommendation, // Get a recommendation based on mood/energy/context
  unknown,        // Could not determine intent
}

/// A fully parsed, structured voice command ready for execution.
class VoiceCommand {
  final VoiceIntent intent;

  /// For searchAndPlay / addToQueue: the search query (song name, artist, etc.)
  final String? query;

  /// For recommendation: the requested mood (e.g. 'chill', 'energetic', 'happy')
  final String? mood;

  /// For recommendation: the energy level ('low', 'medium', 'high')
  final String? energy;

  /// For setVolume: 0–100
  final int? volumePercent;

  /// Human-readable explanation of what will be done (shown in the UI)
  final String? explanation;

  const VoiceCommand({
    required this.intent,
    this.query,
    this.mood,
    this.energy,
    this.volumePercent,
    this.explanation,
  });

  factory VoiceCommand.unknown(String text) => VoiceCommand(
        intent: VoiceIntent.unknown,
        explanation: 'Could not understand: "$text"',
      );

  factory VoiceCommand.fromJson(Map<String, dynamic> json) {
    final intentStr = json['intent'] as String? ?? 'unknown';
    final intent = _parseIntent(intentStr);

    return VoiceCommand(
      intent: intent,
      query: json['query'] as String?,
      mood: json['mood'] as String?,
      energy: json['energy'] as String?,
      volumePercent: (json['volumePercent'] as num?)?.toInt(),
      explanation: json['explanation'] as String?,
    );
  }

  static VoiceIntent _parseIntent(String raw) {
    // Allowlist validation — only known intents are accepted
    const map = {
      'play': VoiceIntent.play,
      'pause': VoiceIntent.pause,
      'stop': VoiceIntent.stop,
      'next': VoiceIntent.next,
      'previous': VoiceIntent.previous,
      'search_and_play': VoiceIntent.searchAndPlay,
      'searchAndPlay': VoiceIntent.searchAndPlay,
      'add_to_queue': VoiceIntent.addToQueue,
      'addToQueue': VoiceIntent.addToQueue,
      'clear_queue': VoiceIntent.clearQueue,
      'clearQueue': VoiceIntent.clearQueue,
      'volume_up': VoiceIntent.volumeUp,
      'volumeUp': VoiceIntent.volumeUp,
      'volume_down': VoiceIntent.volumeDown,
      'volumeDown': VoiceIntent.volumeDown,
      'set_volume': VoiceIntent.setVolume,
      'setVolume': VoiceIntent.setVolume,
      'open_search': VoiceIntent.openSearch,
      'openSearch': VoiceIntent.openSearch,
      'open_liked_songs': VoiceIntent.openLikedSongs,
      'openLikedSongs': VoiceIntent.openLikedSongs,
      'open_playlists': VoiceIntent.openPlaylists,
      'openPlaylists': VoiceIntent.openPlaylists,
      'recommendation': VoiceIntent.recommendation,
    };
    return map[raw] ?? VoiceIntent.unknown;
  }
}

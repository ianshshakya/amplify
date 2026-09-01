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
  openHome,       // Navigate to the home screen
  openSearch,     // Navigate to the search screen
  openLibrary,    // Navigate to the library screen
  openLikedSongs, // Navigate to liked songs
  openPlaylists,  // Navigate to playlists
  recommendation, // Get a recommendation based on mood/energy/context
  chat,           // Conversational response from Bingo
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

  /// For recommendation: AI-suggested songs if the intent is recommendation
  final List<Map<String, String>>? suggestedSongs;

  /// For chat: The conversational response from Bingo
  final String? chatResponse;

  const VoiceCommand({
    required this.intent,
    this.query,
    this.mood,
    this.energy,
    this.volumePercent,
    this.explanation,
    this.suggestedSongs,
    this.chatResponse,
  });

  factory VoiceCommand.unknown(String text) => VoiceCommand(
        intent: VoiceIntent.unknown,
        explanation: 'Could not understand: "$text"',
      );

  factory VoiceCommand.fromJson(Map<String, dynamic> json) {
    final intentStr = json['intent'] as String? ?? 'unknown';
    final intent = _parseIntent(intentStr);

    List<Map<String, String>>? parsedSongs;
    if (json['suggestedSongs'] is List) {
      parsedSongs = (json['suggestedSongs'] as List).map((song) {
        return {
          'title': song['title']?.toString() ?? '',
          'artist': song['artist']?.toString() ?? '',
        };
      }).toList();
    }

    return VoiceCommand(
      intent: intent,
      query: json['query'] as String?,
      mood: json['mood'] as String?,
      energy: json['energy'] as String?,
      volumePercent: (json['volumePercent'] as num?)?.toInt(),
      explanation: json['explanation'] as String?,
      suggestedSongs: parsedSongs,
      chatResponse: json['chatResponse'] as String?,
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
      'open_home': VoiceIntent.openHome,
      'openHome': VoiceIntent.openHome,
      'open_search': VoiceIntent.openSearch,
      'openSearch': VoiceIntent.openSearch,
      'open_library': VoiceIntent.openLibrary,
      'openLibrary': VoiceIntent.openLibrary,
      'open_liked_songs': VoiceIntent.openLikedSongs,
      'openLikedSongs': VoiceIntent.openLikedSongs,
      'open_playlists': VoiceIntent.openPlaylists,
      'openPlaylists': VoiceIntent.openPlaylists,
      'recommendation': VoiceIntent.recommendation,
      'chat': VoiceIntent.chat,
    };
    return map[raw] ?? VoiceIntent.unknown;
  }
}

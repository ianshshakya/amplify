// recommendation_provider.dart — Event-gated providers with session context

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';

// ─── Session context ───────────────────────────────────────────────────────────

@immutable
class SessionContext {
  final List<String> recentSongIds;
  final List<Track> recentTracks;
  final List<String> recentArtists;
  /// Voice-set mood override (e.g. 'chill', 'energetic', 'happy'). Null = no override.
  final String? currentMood;
  /// Voice-set energy override ('low', 'medium', 'high'). Null = no override.
  final String? currentEnergy;
  /// How many consecutive songs the user has skipped this session.
  final int skipStreak;

  const SessionContext({
    this.recentSongIds = const [],
    this.recentTracks = const [],
    this.recentArtists = const [],
    this.currentMood,
    this.currentEnergy,
    this.skipStreak = 0,
  });

  SessionContext addSong(Track track) {
    final newIds = [track.videoId, ...recentSongIds.where((id) => id != track.videoId)].take(10).toList();
    final newTracks = [track, ...recentTracks.where((t) => t.videoId != track.videoId)].take(10).toList();
    
    final artistName = track.artist.split(',').first.trim();
    final newArtists = [...recentArtists];
    if (!newArtists.contains(artistName)) newArtists.insert(0, artistName);
    return SessionContext(
      recentSongIds: newIds,
      recentTracks: newTracks,
      recentArtists: newArtists.take(5).toList(),
      currentMood: currentMood,
      currentEnergy: currentEnergy,
      skipStreak: 0, // reset streak on successful play
    );
  }

  SessionContext recordSkip() => SessionContext(
        recentSongIds: recentSongIds,
        recentTracks: recentTracks,
        recentArtists: recentArtists,
        currentMood: currentMood,
        currentEnergy: currentEnergy,
        skipStreak: skipStreak + 1,
      );

  SessionContext withMoodOverride(String? mood, String? energy) => SessionContext(
        recentSongIds: recentSongIds,
        recentTracks: recentTracks,
        recentArtists: recentArtists,
        currentMood: mood,
        currentEnergy: energy,
        skipStreak: skipStreak,
      );
}

class SessionContextNotifier extends StateNotifier<SessionContext> {
  SessionContextNotifier() : super(const SessionContext());

  void addTrack(Track track) {
    state = state.addSong(track);
  }

  void recordSkip() {
    state = state.recordSkip();
  }

  /// Called by VoiceProvider when user says "play something chill" etc.
  void setMoodOverride(String? mood, String? energy) {
    state = state.withMoodOverride(mood, energy);
  }

  void clear() {
    state = const SessionContext();
  }
}

final sessionContextProvider = StateNotifierProvider<SessionContextNotifier, SessionContext>(
  (ref) => SessionContextNotifier(),
);

// ─── Daily Mix ─────────────────────────────────────────────────────────────────
// Uses AutoDispose + keepAlive to avoid refiring on every rebuild.
// Only refetches after 30 minutes.

final dailyMixProvider = FutureProvider.autoDispose<CuratedPlaylistData?>((ref) async {
  // Keep alive for 30 minutes to prevent rebuild-triggered refetches
  final keepAliveLink = ref.keepAlive();

  Future.delayed(const Duration(minutes: 30), () {
    keepAliveLink.close();
  });

  try {
    return await MusicService().getDailyMix();
  } catch (e) {
    debugPrint('dailyMixProvider error: $e');
    return null;
  }
});

// ─── Recent Tracks ────────────────────────────────────────────────────────────

final recentTracksProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  try {
    return await MusicService().getRecentTracks();
  } catch (e) {
    debugPrint('recentTracksProvider error: $e');
    return [];
  }
});

// ─── Next tracks provider (for autoplay) ─────────────────────────────────────
// Triggered explicitly by the player when the queue runs out.

class NextTracksNotifier extends StateNotifier<AsyncValue<List<Track>>> {
  NextTracksNotifier() : super(const AsyncValue.data([]));

  Future<List<Track>> fetchNext(Track currentSong, SessionContext sessionCtx) async {
    state = const AsyncValue.loading();
    try {
      final tracks = await MusicService().getNextTracks(currentSong, sessionCtx);
      state = AsyncValue.data(tracks);
      return tracks;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return [];
    }
  }
}

final nextTracksProvider = StateNotifierProvider<NextTracksNotifier, AsyncValue<List<Track>>>(
  (ref) => NextTracksNotifier(),
);

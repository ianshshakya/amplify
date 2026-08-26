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
  final List<String> recentArtists;

  const SessionContext({
    this.recentSongIds = const [],
    this.recentArtists = const [],
  });

  SessionContext addSong(Track track) {
    final newIds = [...recentSongIds, track.videoId].take(10).toList();
    final artistName = track.artist.split(',').first.trim();
    final newArtists = [...recentArtists];
    if (!newArtists.contains(artistName)) newArtists.insert(0, artistName);
    return SessionContext(
      recentSongIds: newIds,
      recentArtists: newArtists.take(5).toList(),
    );
  }
}

class SessionContextNotifier extends StateNotifier<SessionContext> {
  SessionContextNotifier() : super(const SessionContext());

  void addTrack(Track track) {
    state = state.addSong(track);
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

// ─── One Song Away ────────────────────────────────────────────────────────────

final oneSongAwayProvider = FutureProvider.autoDispose<Track?>((ref) async {
  final keepAliveLink = ref.keepAlive();
  Future.delayed(const Duration(minutes: 30), () {
    keepAliveLink.close();
  });

  try {
    return await MusicService().getOneSongAway();
  } catch (e) {
    debugPrint('oneSongAwayProvider error: $e');
    return null;
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

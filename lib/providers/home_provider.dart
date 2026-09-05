import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/mood_category.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/lyrics.dart';
import '../models/home_feed.dart';
import '../services/music_service.dart';
import 'recommendation_provider.dart';

/// Refreshes only on explicit invalidation/pull-to-refresh. Session mood and
/// energy are sent as soft context signals; recommendation calculation stays
/// on the backend.
final homeRefreshProvider = StateProvider<bool>((_) => false);

final dynamicHomeFeedProvider = FutureProvider.autoDispose<HomeFeed?>((ref) async {
  final forceRefresh = ref.watch(homeRefreshProvider);
  final session = ref.read(sessionContextProvider);
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 15), link.close);
  final feed = await MusicService().getDynamicHomeFeed(mood: session.currentMood, energy: session.currentEnergy, forceRefresh: forceRefresh);
  if (forceRefresh) ref.read(homeRefreshProvider.notifier).state = false;
  return feed;
});

/// FutureProvider for the home-screen curated feed (personalized playlist metadata).
final homeFeedProvider = FutureProvider<List<CuratedPlaylist>>(
  (ref) => MusicService().getHomeFeed(),
);

/// FutureProvider for trending charts tracks.
final chartsProvider = FutureProvider<List<Track>>(
  (ref) => MusicService().getCharts(),
);

/// FutureProvider for mood/genre browsing categories.
final moodCategoriesProvider = FutureProvider<List<MoodCategory>>(
  (ref) => MusicService().getMoodCategories(),
);

/// Family FutureProvider for a specific curated playlist by id.
final curatedPlaylistProvider =
    FutureProvider.family<CuratedPlaylistData?, String>(
  (ref, id) => MusicService().getCuratedPlaylist(id),
);

/// Family FutureProvider for full artist data by artistId.
final artistDetailProvider = FutureProvider.family<Artist?, String>(
  (ref, artistId) => MusicService().getArtist(artistId),
);

/// Family FutureProvider for full album data by albumId.
final albumDetailProvider = FutureProvider.family<Album?, String>(
  (ref, albumId) => MusicService().getAlbum(albumId),
);

/// Family FutureProvider for lyrics by videoId.
final lyricsProvider = FutureProvider.family<Lyrics?, String>(
  (ref, videoId) => MusicService().getLyrics(videoId),
);

// ─── NEW: Song of the Day — same for ALL users, date-seeded ──────────────────
// Kept alive for 6 hours so it doesn't change while the user is in the app.
final songOfTheDayProvider = FutureProvider.autoDispose<Track?>((ref) async {
  final link = ref.keepAlive();
  Future.delayed(const Duration(hours: 6), () => link.close());
  return MusicService().getSongOfTheDay();
});

// ─── NEW: Made For You — multiple user-specific playlist stubs ───────────────
// Kept alive for 30 minutes.
final madeForYouProvider = FutureProvider.autoDispose<List<CuratedPlaylistData>>((ref) async {
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 30), () => link.close());
  return MusicService().getMadeForYouPlaylists();
});

// ─── NEW: Top Artists from user taste profile ─────────────────────────────────
// Kept alive for 30 minutes.
final topArtistsProvider = FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 30), () => link.close());
  return MusicService().getTopArtists();
});

// ─── NEW: Discover tracks from underexplored taste areas ─────────────────────
final discoverTracksProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 20), () => link.close());
  return MusicService().getDiscoverTracks();
});

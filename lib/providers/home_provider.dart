import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/mood_category.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/lyrics.dart';
import '../services/music_service.dart';

/// FutureProvider for the home-screen curated feed (5 curated playlists).
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

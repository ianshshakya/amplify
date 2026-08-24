import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../services/music_service.dart';

final dailyMixProvider = FutureProvider<CuratedPlaylistData?>((ref) async {
  return await MusicService().getDailyMix();
});

final oneSongAwayProvider = FutureProvider<Track?>((ref) async {
  return await MusicService().getOneSongAway();
});

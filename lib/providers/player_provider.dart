import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import '../models/track.dart';
import '../services/music_service.dart';
import '../services/offline_service.dart';
import '../services/user_data_service.dart';
import '../services/api_client.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

enum RepeatMode { off, all, one }
enum PlaybackStatus { idle, loading, playing, paused, error }

@immutable
class PlayerState {
  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final PlaybackStatus status;
  final String? errorMessage;
  final RepeatMode repeatMode;
  final bool shuffleEnabled;
  final Duration duration;

  const PlayerState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = -1,
    this.status = PlaybackStatus.idle,
    this.errorMessage,
    this.repeatMode = RepeatMode.off,
    this.shuffleEnabled = false,
    this.duration = Duration.zero,
  });

  PlayerState copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    PlaybackStatus? status,
    String? errorMessage,
    RepeatMode? repeatMode,
    bool? shuffleEnabled,
    Duration? duration,
    bool clearTrack = false,
    bool clearError = false,
  }) =>
      PlayerState(
        currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        status: status ?? this.status,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        repeatMode: repeatMode ?? this.repeatMode,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        duration: duration ?? this.duration,
      );
}

/// Central playback controller.
/// Uses Riverpod StateNotifier so any ConsumerWidget can listen to the player state.

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicService _musicService = MusicService();
  final UserDataService _userDataService = UserDataService();

  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  PlayerNotifier() : super(const PlayerState()) {
    _audioPlayer.playerStateStream.listen((audioState) {
      PlaybackStatus nextStatus = state.status;
      if (state.status != PlaybackStatus.error) {
        if (audioState.processingState == ProcessingState.buffering || audioState.processingState == ProcessingState.loading) {
          nextStatus = PlaybackStatus.loading;
        } else if (audioState.playing) {
          nextStatus = PlaybackStatus.playing;
        } else {
          nextStatus = PlaybackStatus.paused;
        }
      }
      
      state = state.copyWith(
        status: nextStatus,
      );
      if (audioState.processingState == ProcessingState.completed) {
        _handleTrackCompletion();
      }
    });

    _audioPlayer.durationStream.listen((d) {
      if (d != null) state = state.copyWith(duration: d);
    });
  }

  // ─── Playback control ──────────────────────────────────────────────────────

  Future<void> playTrack(Track track, {List<Track>? context}) async {
    final queue = context ?? [track];
    var idx = queue.indexWhere((t) => t.videoId == track.videoId);
    if (idx == -1) idx = 0;

    state = state.copyWith(
      queue: queue,
      currentIndex: idx,
      currentTrack: track,
    );
    await _loadAndPlayCurrent();
  }

  Future<void> _loadAndPlayCurrent() async {
    final track = _currentTrack;
    if (track == null) return;

    state = state.copyWith(status: PlaybackStatus.loading, currentTrack: track, clearError: true);
    await _audioPlayer.stop(); // Stop previous song to prevent playing old audio if new fetch fails

    try {
      final offlineService = OfflineService();
      final localUri = await offlineService.getLocalUri(track.videoId);

      late AudioSource audioSource;

      if (localUri != null) {
        debugPrint('[Player] Playing offline: $localUri');
        audioSource = AudioSource.uri(
          localUri,
          tag: _makeMediaItem(track),
        );
      } else {
        String streamUrl;
        if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
          debugPrint('[Player] Using direct stream URL for ${track.title}');
          streamUrl = track.streamUrl!;
        } else {
          debugPrint('[Player] Fetching stream for ${track.videoId}...');
          streamUrl = await _musicService.getAudioStreamUrl(track.videoId);
        }
        
        audioSource = AudioSource.uri(
          Uri.parse(streamUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/114.0.0.0 Safari/537.36',
          },
          tag: _makeMediaItem(track),
        );
      }

      await _audioPlayer.setAudioSource(audioSource);
      _audioPlayer.play();

      _userDataService.logWatchHistory(track).catchError((_) {});
    } on StreamUnavailableException catch (e) {
      debugPrint('[Player] Stream unavailable: $e');
      state = state.copyWith(status: PlaybackStatus.error, errorMessage: e.message);
    } catch (e) {
      debugPrint('[Player] Error loading ${track.title}: $e');
      state = state.copyWith(status: PlaybackStatus.error, errorMessage: "Couldn't play this song — please try another.");
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  Future<void> playNext() async {
    if (state.queue.isEmpty) return;

    int nextIndex;
    if (state.shuffleEnabled) {
      nextIndex = state.queue.length > 1
          ? (state.currentIndex +
                  1 +
                  DateTime.now().millisecond % (state.queue.length - 1)) %
              state.queue.length
          : 0;
    } else if (state.currentIndex < state.queue.length - 1) {
      nextIndex = state.currentIndex + 1;
    } else if (state.repeatMode == RepeatMode.all) {
      nextIndex = 0;
    } else {
      // End of queue — try fetching radio/watch playlist
      _appendRadioTracks();
      return;
    }

    state = state.copyWith(
      currentIndex: nextIndex,
      currentTrack: state.queue[nextIndex],
    );
    await _loadAndPlayCurrent();
  }

  Future<void> playPrevious() async {
    if (state.queue.isEmpty) return;

    // If > 3 sec into the track, restart instead
    if (_audioPlayer.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    if (state.currentIndex > 0) {
      final newIdx = state.currentIndex - 1;
      state = state.copyWith(
        currentIndex: newIdx,
        currentTrack: state.queue[newIdx],
      );
      await _loadAndPlayCurrent();
    } else {
      await seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
  }

  void cycleRepeatMode() {
    final next = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  void addToQueue(Track track) {
    if (!state.queue.any((t) => t.videoId == track.videoId)) {
      state = state.copyWith(queue: [...state.queue, track]);
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final newQueue = [...state.queue]..removeAt(index);
    // Adjust current index if needed
    int newIdx = state.currentIndex;
    if (index < state.currentIndex) newIdx--;
    state = state.copyWith(queue: newQueue, currentIndex: newIdx.clamp(0, newQueue.length - 1));
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final q = [...state.queue];
    final item = q.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    q.insert(insertAt, item);
    int newCurrent = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrent = insertAt;
    } else if (oldIndex < state.currentIndex && insertAt >= state.currentIndex) {
      newCurrent--;
    } else if (oldIndex > state.currentIndex && insertAt <= state.currentIndex) {
      newCurrent++;
    }
    state = state.copyWith(queue: q, currentIndex: newCurrent);
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Track? get _currentTrack {
    final idx = state.currentIndex;
    if (idx < 0 || idx >= state.queue.length) return null;
    return state.queue[idx];
  }

  void _handleTrackCompletion() {
    if (state.repeatMode == RepeatMode.one) {
      seek(Duration.zero);
      _audioPlayer.play();
    } else {
      playNext();
    }
  }

  /// Silently append YT Music radio tracks when the queue runs out.
  Future<void> _appendRadioTracks() async {
    final current = _currentTrack;
    if (current == null) return;
    try {
      final radio = await _musicService.getWatchPlaylist(current.videoId);
      if (radio.isNotEmpty) {
        final newQueue = [...state.queue, ...radio];
        final newIdx = state.currentIndex + 1;
        state = state.copyWith(
          queue: newQueue,
          currentIndex: newIdx,
          currentTrack: newQueue[newIdx],
        );
        await _loadAndPlayCurrent();
      }
    } catch (_) {}
  }

  MediaItem _makeMediaItem(Track track) => MediaItem(
        id: track.videoId,
        title: track.title,
        artist: track.artist,
        artUri: Uri.tryParse(track.thumbnailUrl),
        duration: track.duration,
      );

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(),
);

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import '../models/track.dart';
import '../services/music_service.dart';
import '../services/offline_service.dart';
import '../services/user_data_service.dart';
import '../services/api_client.dart';

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
  ConcatenatingAudioSource? _playlistSource;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  bool _isPrefetching = false;

  PlayerNotifier() : super(const PlayerState()) {
    _audioPlayer.playerStateStream.listen((audioState) {
      PlaybackStatus nextStatus = state.status;
      if (state.status != PlaybackStatus.error) {
        if (audioState.processingState == ProcessingState.completed) {
          nextStatus = PlaybackStatus.paused;
        } else if (audioState.playing && audioState.processingState == ProcessingState.ready) {
          nextStatus = PlaybackStatus.playing;
        } else if (audioState.playing && audioState.processingState == ProcessingState.buffering) {
          // just_audio sometimes reports buffering even while audio is actively playing on Windows.
          // We can assume if position > 0 and playing is true, we should show playing UI.
          if (_audioPlayer.position.inMilliseconds > 0) {
             nextStatus = PlaybackStatus.playing;
          } else {
             nextStatus = PlaybackStatus.loading;
          }
        } else if (audioState.processingState == ProcessingState.loading || audioState.processingState == ProcessingState.buffering) {
          nextStatus = PlaybackStatus.loading;
        } else if (!audioState.playing) {
          nextStatus = PlaybackStatus.paused;
        }
      }
      
      state = state.copyWith(status: nextStatus);

      // If we finished playing the entire concatenating source, check what to do
      if (audioState.processingState == ProcessingState.completed) {
        if (state.repeatMode == RepeatMode.one) {
          _audioPlayer.seek(Duration.zero, index: _audioPlayer.currentIndex);
          _audioPlayer.play();
        } else {
          // If it reached the end, maybe we need radio
          _appendRadioTracksIfNeeded();
        }
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      // If UI is stuck on loading but audio is actually advancing, force playing state
      if (state.status == PlaybackStatus.loading && pos.inMilliseconds > 0 && _audioPlayer.playing) {
        state = state.copyWith(status: PlaybackStatus.playing);
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && index < state.queue.length) {
        state = state.copyWith(
          currentIndex: index,
          currentTrack: state.queue[index],
        );
        _prefetchNext(); // Trigger prefetch for the next song when current changes
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
      status: PlaybackStatus.loading,
      clearError: true,
    );

    try {
      await _audioPlayer.stop();

      final source = await _buildAudioSource(track);
      _playlistSource = ConcatenatingAudioSource(children: [source]);
      
      await _audioPlayer.setAudioSource(
        _playlistSource!, 
        initialIndex: 0, 
        initialPosition: Duration.zero
      );
      
      _audioPlayer.play();

      _userDataService.logWatchHistory(track).catchError((_) {});

      // Prefetch the next track right away
      _prefetchNext();

    } on StreamUnavailableException catch (e) {
      debugPrint('[Player] Stream unavailable: $e');
      state = state.copyWith(status: PlaybackStatus.error, errorMessage: e.message);
    } catch (e) {
      debugPrint('[Player] Error loading ${track.title}: $e');
      state = state.copyWith(status: PlaybackStatus.error, errorMessage: "Couldn't play this song — please try another.");
    }
  }

  Future<AudioSource> _buildAudioSource(Track track) async {
    final offlineService = OfflineService();
    final localUri = await offlineService.getLocalUri(track.videoId);

    if (localUri != null) {
      return AudioSource.uri(
        localUri,
        tag: _makeMediaItem(track),
      );
    } else {
      String streamUrl;
      if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
        streamUrl = track.streamUrl!;
      } else {
        try {
          final apiClient = ApiClient();
          final res = await apiClient.get('/music/stream/${track.videoId}');
          if (res != null && res['streamUrl'] != null) {
            streamUrl = res['streamUrl'];
          } else {
            throw Exception('Stream URL not found in backend response');
          }
        } catch (e) {
          throw StreamUnavailableException(500, 'Failed to fetch stream from backend: $e');
        }
      }
      return AudioSource.uri(
        Uri.parse(streamUrl),
        tag: _makeMediaItem(track),
      );
    }
  }

  Future<void> _prefetchNext() async {
    if (_isPrefetching || state.queue.isEmpty) return;
    
    final currentIndex = state.currentIndex;
    // Calculate what the next index will be
    int nextIndex;
    if (state.shuffleEnabled) {
      nextIndex = state.queue.length > 1
          ? (currentIndex + 1 + DateTime.now().millisecond % (state.queue.length - 1)) % state.queue.length
          : 0;
    } else if (currentIndex < state.queue.length - 1) {
      nextIndex = currentIndex + 1;
    } else if (state.repeatMode == RepeatMode.all) {
      nextIndex = 0;
    } else {
      return; // No next track
    }

    // Only prefetch if we haven't already appended it to the playlistSource
    // just_audio's playlist source length will tell us if we already appended
    if (_playlistSource != null && _playlistSource!.length > _audioPlayer.currentIndex! + 1) {
      return; // Already prefetched
    }

    _isPrefetching = true;
    try {
      final nextTrack = state.queue[nextIndex];
      final source = await _buildAudioSource(nextTrack);
      await _playlistSource?.add(source);
      
      // Update the queue so that the physical queue order matches the playlistSource order
      if (nextIndex != currentIndex + 1) {
        // If shuffled or repeated, we need to ensure state.queue reflects this physically 
        // for the currentIndexStream listener to map correctly.
        // But for simplicity, gapless shuffle is complex. We'll just append it to state.queue if needed.
        // Actually, just append to state.queue so currentIndex matches length.
        final updatedQueue = [...state.queue];
        if (nextIndex == 0 && state.repeatMode == RepeatMode.all) {
           updatedQueue.add(nextTrack);
           state = state.copyWith(queue: updatedQueue);
        } else if (state.shuffleEnabled) {
           updatedQueue.insert(currentIndex + 1, nextTrack);
           state = state.copyWith(queue: updatedQueue);
        }
      }
    } catch (e) {
      debugPrint('[Player] Prefetch failed: $e');
    } finally {
      _isPrefetching = false;
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
    if (_audioPlayer.hasNext) {
      await _audioPlayer.seekToNext();
    } else {
      await _appendRadioTracksIfNeeded();
    }
  }

  Future<void> playPrevious() async {
    if (_audioPlayer.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
    } else if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
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
    _audioPlayer.setLoopMode(next == RepeatMode.one ? LoopMode.one : LoopMode.off);
  }

  void addToQueue(Track track) {
    if (!state.queue.any((t) => t.videoId == track.videoId)) {
      state = state.copyWith(queue: [...state.queue, track]);
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final newQueue = [...state.queue]..removeAt(index);
    int newIdx = state.currentIndex;
    if (index < state.currentIndex) newIdx--;
    state = state.copyWith(queue: newQueue, currentIndex: newIdx.clamp(0, newQueue.length - 1));
  }

  void reorderQueue(int oldIndex, int newIndex) {
    // Reordering with ConcatenatingAudioSource is more complex, but we update the UI queue here.
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

  /// Silently append YT Music radio tracks when the queue runs out.
  Future<void> _appendRadioTracksIfNeeded() async {
    if (_isPrefetching) return;
    final current = state.currentTrack;
    if (current == null) return;
    
    _isPrefetching = true;
    try {
      final radio = await _musicService.getWatchPlaylist(current.videoId);
      if (radio.isNotEmpty) {
        final newQueue = [...state.queue, ...radio];
        state = state.copyWith(queue: newQueue);
        
        // Add the first radio track to the playlist source so it plays next seamlessly
        final nextTrack = radio.first;
        final source = await _buildAudioSource(nextTrack);
        await _playlistSource?.add(source);
      }
    } catch (_) {
    } finally {
      _isPrefetching = false;
    }
  }

  MediaItem _makeMediaItem(Track track) => MediaItem(
        id: '${track.videoId}_${DateTime.now().microsecondsSinceEpoch}',
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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import '../models/track.dart';
import '../services/music_service.dart';
import '../services/offline_service.dart';
import '../services/user_data_service.dart';
import '../services/api_client.dart';
import 'recommendation_provider.dart' show sessionContextProvider;

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
  Ref? _ref; // Injected so we can access sessionContextProvider

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  bool _isFetchingRadio = false;

  PlayerNotifier({Ref? ref}) : super(const PlayerState()) {
    _ref = ref;
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
        if (state.currentTrack != null) {
           _musicService.logListeningEvent(state.currentTrack!, 'COMPLETE', completionPercent: 100).catchError((_) {});
        }
        
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

      // Adaptive Radio Fetching: If we are nearing the end of the entire queue, fetch radio tracks.
      final duration = _audioPlayer.duration?.inMilliseconds ?? 0;
      if (duration > 0 && state.currentIndex >= state.queue.length - 2 && !_isFetchingRadio) {
        final percent = (pos.inMilliseconds / duration) * 100;
        if (percent > 70) {
          _appendRadioTracksIfNeeded();
        }
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && index < state.queue.length) {
        final newTrack = state.queue[index];
        state = state.copyWith(
          currentIndex: index,
          currentTrack: newTrack,
        );
        // Update session context so radio knows what we've been listening to
        _ref?.read(sessionContextProvider.notifier).addTrack(newTrack);
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

      // Instantly load the entire queue so skipping is perfectly seamless
      final sources = await Future.wait(queue.map((t) => _buildAudioSource(t)));
      _playlistSource = ConcatenatingAudioSource(children: sources);
      
      await _audioPlayer.setAudioSource(
        _playlistSource!, 
        initialIndex: idx, 
        initialPosition: Duration.zero
      );
      
      _audioPlayer.play();

      _userDataService.logWatchHistory(track).catchError((_) {});

      // Dispatch PLAY event to the self-learning engine
      _musicService.logListeningEvent(track, 'PLAY').catchError((_) {});

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
      // Use the direct streaming proxy to stream bytes instantly in packets
      final streamUrl = track.streamUrl != null && track.streamUrl!.isNotEmpty
          ? track.streamUrl!
          : '${ApiClient.baseUrl}/music/play/${track.videoId}';

      return AudioSource.uri(
        Uri.parse(streamUrl),
        tag: _makeMediaItem(track),
      );
    }
  }

  // Native prefetching is handled instantly since we construct the queue upfront.

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  Future<void> playNext() async {
    if (state.currentTrack != null) {
      // If we manually play next, we consider it a SKIP or a COMPLETE based on position
      final durationMs = state.duration.inMilliseconds;
      final posMs = _audioPlayer.position.inMilliseconds;
      final percent = durationMs > 0 ? (posMs / durationMs) * 100 : 0;

      // Log EARLY_SKIP if skipped before 20% — strong negative signal
      final eventType = percent >= 90 ? 'COMPLETE' : (percent < 20 ? 'EARLY_SKIP' : 'SKIP');
      _musicService.logListeningEvent(
        state.currentTrack!,
        eventType,
        durationMs: posMs,
        completionPercent: percent.toInt(),
      ).catchError((_) {});
    }

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
    final nextMode = !state.shuffleEnabled;
    state = state.copyWith(shuffleEnabled: nextMode);
    _audioPlayer.setShuffleModeEnabled(nextMode);
    if (nextMode) {
      _audioPlayer.shuffle();
    }
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

  Future<void> addToQueue(Track track) async {
    if (!state.queue.any((t) => t.videoId == track.videoId)) {
      final source = await _buildAudioSource(track);
      await _playlistSource?.add(source);
      state = state.copyWith(queue: [...state.queue, track]);
    }
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    await _playlistSource?.removeAt(index);
    final newQueue = [...state.queue]..removeAt(index);
    int newIdx = state.currentIndex;
    if (index < state.currentIndex) newIdx--;
    state = state.copyWith(queue: newQueue, currentIndex: newIdx.clamp(0, newQueue.length - 1));
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || newIndex < 0 || oldIndex >= state.queue.length) return;
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    
    await _playlistSource?.move(oldIndex, insertAt);

    final q = [...state.queue];
    final item = q.removeAt(oldIndex);
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

  /// Silently append algorithmic infinite radio tracks when the queue runs out.
  Future<void> _appendRadioTracksIfNeeded() async {
    if (_isFetchingRadio) return;
    final current = state.currentTrack;
    if (current == null) return;

    _isFetchingRadio = true;
    try {
      // Use session context for smarter radio (knows what's been playing)
      final sessionCtx = _ref?.read(sessionContextProvider);
      final radio = await _musicService.getNextTracks(current, sessionCtx);

      if (radio.isNotEmpty) {
        // Filter out songs already in the queue
        final existingIds = state.queue.map((t) => t.videoId).toSet();
        final newTracks = radio.where((t) => !existingIds.contains(t.videoId)).toList();

        if (newTracks.isNotEmpty) {
          final sources = await Future.wait(newTracks.map((t) => _buildAudioSource(t)));
          await _playlistSource?.addAll(sources);
          
          final newQueue = [...state.queue, ...newTracks];
          state = state.copyWith(queue: newQueue);
        }
      }
    } catch (_) {
    } finally {
      _isFetchingRadio = false;
    }
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
  (ref) => PlayerNotifier(ref: ref),
);

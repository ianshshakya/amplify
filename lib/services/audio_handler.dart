import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';

class AmplifyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // Callbacks
  void Function(Track track)? onLike;
  
  // Current track metadata tracking
  Track? _currentTrack;

  AmplifyAudioHandler() {
    // Broadcast player state changes to audio_service
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          const MediaControl(
            androidIcon: 'drawable/ic_heart', // You must create this icon or use a system one if preferred
            label: 'Like',
            action: MediaAction.custom,
          ),
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    });

    // Automatically sync the current media item from just_audio's sequence
    _player.sequenceStateStream.listen((sequenceState) {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
      final index = sequenceState?.currentIndex;
      if (index != null && index < sequence.length) {
        final currentSource = sequence[index];
        if (currentSource.tag is MediaItem) {
          mediaItem.add(currentSource.tag as MediaItem);
        }
      }
    });
  }

  // Allow exposing the internal player for UI progress bars and queue management
  AudioPlayer get player => _player;
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get position => _player.position;
  bool get hasNext => _player.hasNext;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'like' && mediaItem.value != null) {
      // Find the track model based on the mediaItem id
      final track = Track(
        videoId: mediaItem.value!.id,
        title: mediaItem.value!.title,
        artist: mediaItem.value!.artist ?? 'Unknown',
        thumbnailUrl: mediaItem.value!.artUri?.toString() ?? '',
        duration: mediaItem.value!.duration ?? Duration.zero,
      );
      onLike?.call(track);
    }
    super.customAction(name, extras);
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);
}

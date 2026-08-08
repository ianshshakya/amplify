import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import '../models/track.dart';
import '../services/music_service.dart';
import '../services/user_data_service.dart';
import '../services/offline_service.dart';

enum RepeatMode { off, all, one }

/// Central playback controller. Every screen that needs to know "what's
/// playing right now" or wants to control playback (mini player, full
/// player screen, track tiles) listens to this via Provider.
class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicService _musicService = MusicService();
  final UserDataService _userDataService = UserDataService();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffle = false;

  Track? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  List<Track> get queue => _queue;
  bool get isLoading => _isLoading;
  bool get isPlaying => _audioPlayer.playing;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleEnabled => _shuffle;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Duration get duration => _audioPlayer.duration ?? currentTrack?.duration ?? Duration.zero;

  PlayerProvider() {
    // Auto-advance to the next track when the current one finishes.
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompletion();
      }
      notifyListeners();
    });
  }

  /// Play a track immediately, replacing the current queue with [context]
  /// (e.g. the search results list or a playlist) so next/previous work.
  Future<void> playTrack(Track track, {List<Track>? context}) async {
    _queue = context ?? [track];
    _currentIndex = _queue.indexWhere((t) => t.videoId == track.videoId);
    if (_currentIndex == -1) {
      _queue = [track];
      _currentIndex = 0;
    }
    await _loadAndPlayCurrent();
  }

  Future<void> _loadAndPlayCurrent() async {
    final track = currentTrack;
    if (track == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final offlineService = OfflineService();
      final localUri = await offlineService.getLocalUri(track.videoId);
      
      late AudioSource audioSource;
      
      if (localUri != null) {
        debugPrint('Playing offline file: $localUri');
        audioSource = AudioSource.uri(
          localUri,
          tag: MediaItem(
            id: track.videoId,
            title: track.title,
            artist: track.artist,
            artUri: Uri.tryParse(track.thumbnailUrl),
            duration: track.duration,
          ),
        );
      } else {
        debugPrint('Playing network stream...');
        final streamUrl = await _musicService.getAudioStreamUrl(track.videoId);
        
        audioSource = AudioSource.uri(
          Uri.parse(streamUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
          },
          tag: MediaItem(
            id: track.videoId,
            title: track.title,
            artist: track.artist,
            artUri: Uri.tryParse(track.thumbnailUrl),
            duration: track.duration,
          ),
        );
        
        // Removed automatic background download here.
        // Users will manually download using the UI button.
      }

      await _audioPlayer.setAudioSource(audioSource);
      
      // Do NOT await play(), because it only completes when the song finishes!
      // This caused the endless spinner.
      _audioPlayer.play();

      // Fire-and-forget: log this play to watch history
      _userDataService.logWatchHistory(track).catchError((e) {
        debugPrint('Failed to log watch history: $e');
      });
    } catch (e) {
      debugPrint('Playback error for ${track.title}: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;

    if (_shuffle) {
      _currentIndex = (_queue.length > 1)
          ? (_currentIndex + 1 + (DateTime.now().millisecond % (_queue.length - 1))) % _queue.length
          : 0;
    } else if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
    } else {
      return; // End of queue, nothing to play.
    }
    await _loadAndPlayCurrent();
  }

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;

    // If we're more than 3 seconds into the track, restart it instead
    // of going to the previous track (standard music-player behavior).
    final pos = _audioPlayer.position;
    if (pos > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      await _loadAndPlayCurrent();
    } else {
      await seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    notifyListeners();
  }

  void _handleTrackCompletion() {
    if (_repeatMode == RepeatMode.one) {
      seek(Duration.zero);
      _audioPlayer.play();
    } else {
      playNext();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _musicService.dispose();
    super.dispose();
  }
}

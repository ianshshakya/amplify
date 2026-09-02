import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/voice_command.dart';
import '../providers/player_provider.dart';
import '../providers/recommendation_provider.dart';
import '../services/voice_service.dart';
import '../services/voice_command_parser.dart';
import '../services/music_service.dart';
import '../services/wake_word_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

enum VoiceAssistantState {
  disabled,
  idle,                // Mic button available, not active
  waitingForWakeWord,  // Background listening for "Hey Bingo"
  wakeDetected,        // Wake word heard, ducking audio
  listeningForCommand, // Recording user speech
  processing,          // Running command through NLP
  executing,           // Executing player action
  error,
  success,
}

@immutable
class VoiceState {
  final VoiceAssistantState feedback;
  final String recognizedText;
  final String feedbackMessage;
  final VoiceCommand? lastCommand;
  final bool isHandsFreeEnabled;

  const VoiceState({
    this.feedback = VoiceAssistantState.idle,
    this.recognizedText = '',
    this.feedbackMessage = '',
    this.lastCommand,
    this.isHandsFreeEnabled = false,
  });

  VoiceState copyWith({
    VoiceAssistantState? feedback,
    String? recognizedText,
    String? feedbackMessage,
    VoiceCommand? lastCommand,
    bool? isHandsFreeEnabled,
  }) =>
      VoiceState(
        feedback: feedback ?? this.feedback,
        recognizedText: recognizedText ?? this.recognizedText,
        feedbackMessage: feedbackMessage ?? this.feedbackMessage,
        lastCommand: lastCommand ?? this.lastCommand,
        isHandsFreeEnabled: isHandsFreeEnabled ?? this.isHandsFreeEnabled,
      );
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  return VoiceNotifier(ref);
});

class VoiceNotifier extends StateNotifier<VoiceState> {
  final Ref _ref;
  final VoiceService _voiceService = VoiceService();
  final VoiceCommandParser _parser = VoiceCommandParser();
  final MusicService _musicService = MusicService();
  final WakeWordService _wakeWordService = WakeWordService();
  
  Timer? _initialSilenceTimer;
  StreamSubscription? _wakeWordSub;

  VoiceNotifier(this._ref) : super(const VoiceState()) {
    _init();
  }

  Future<void> _init() async {
    // Always enable hands-free (Bingo) on startup as requested
    await enableHandsFree();
  }

  @override
  void dispose() {
    _wakeWordSub?.cancel();
    _wakeWordService.dispose();
    super.dispose();
  }

  Future<void> enableHandsFree() async {
    // Request microphone permission before starting
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _setError('Microphone permission is required for Hands-Free mode.');
      return;
    }

    final success = await _wakeWordService.start();
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hands_free_enabled', true);
      
      _wakeWordSub?.cancel();
      _wakeWordSub = _wakeWordService.wakeWordDetected.listen((_) {
        handleWakeWordDetected();
      });

      state = state.copyWith(
        isHandsFreeEnabled: true,
        feedback: VoiceAssistantState.waitingForWakeWord,
      );
    } else {
      _setError('Failed to start wake word engine.');
    }
  }

  Future<void> disableHandsFree() async {
    await _wakeWordService.stop();
    _wakeWordSub?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hands_free_enabled', false);
    
    state = state.copyWith(
      isHandsFreeEnabled: false,
      feedback: VoiceAssistantState.idle,
    );
  }

  Future<void> toggleHandsFree() async {
    if (state.isHandsFreeEnabled) {
      await disableHandsFree();
    } else {
      await enableHandsFree();
    }
  }


  Future<void> handleWakeWordDetected() async {
    if (state.feedback == VoiceAssistantState.listeningForCommand || 
        state.feedback == VoiceAssistantState.processing) {
      return; // Already busy
    }

    state = state.copyWith(feedback: VoiceAssistantState.wakeDetected);
    
    // Audio ducking
    final player = _ref.read(playerProvider.notifier);
    final wasPlaying = _ref.read(playerProvider).isPlaying;
    if (wasPlaying) {
      await player.setVolume(0.2); // Duck volume
    }

    await startListening();
    
    // Restore volume after listening completes is handled in _cleanupAfterCommand
  }

  Future<void> startListening() async {
    if (state.feedback == VoiceAssistantState.listeningForCommand) return;

    state = state.copyWith(
      feedback: VoiceAssistantState.listeningForCommand,
      feedbackMessage: 'Listening…',
      recognizedText: '',
    );

    String recognized = '';
    _initialSilenceTimer?.cancel();
    _initialSilenceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && state.feedback == VoiceAssistantState.listeningForCommand && state.recognizedText.isEmpty) {
        _voiceService.stopListening();
        _setError("Didn't hear anything — try again.");
      }
    });

    final started = await _voiceService.startListening(
      onResult: (text, isFinal) {
        if (text.isNotEmpty) {
          _initialSilenceTimer?.cancel();
        }
        recognized = text;
        state = state.copyWith(recognizedText: text);
        if (isFinal && text.isNotEmpty) {
          _handleFinalResult(text);
        }
      },
      onDone: () async {
        _initialSilenceTimer?.cancel();
        if (state.feedback == VoiceAssistantState.listeningForCommand) {
          if (recognized.isEmpty) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted && state.feedback == VoiceAssistantState.listeningForCommand) {
              if (recognized.isEmpty) {
                reset();
              } else {
                _handleFinalResult(recognized);
              }
            }
          } else {
            _handleFinalResult(recognized);
          }
        }
      },
    );

    if (!started) {
      _setError('Microphone unavailable. Check permissions.');
      _cleanupAfterCommand();
    }
  }

  Future<void> stopListening() async {
    _initialSilenceTimer?.cancel();
    if (state.feedback != VoiceAssistantState.listeningForCommand) return;
    await _voiceService.stopListening();
  }

  Future<void> toggleListening() async {
    if (state.feedback == VoiceAssistantState.listeningForCommand) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  void reset() {
    _cleanupAfterCommand();
    state = state.copyWith(
      feedback: state.isHandsFreeEnabled ? VoiceAssistantState.waitingForWakeWord : VoiceAssistantState.idle,
      recognizedText: '',
      feedbackMessage: '',
    );
    if (state.isHandsFreeEnabled) {
      // We must tell the native side to resume listening for the wake word
      _wakeWordService.start();
    }
  }

  void _setError(String message) {
    _cleanupAfterCommand();
    state = state.copyWith(
      feedback: VoiceAssistantState.error,
      feedbackMessage: message,
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && state.feedback == VoiceAssistantState.error) reset();
    });
  }

  void _setSuccess(String message) {
    _cleanupAfterCommand();
    state = state.copyWith(
      feedback: VoiceAssistantState.success,
      feedbackMessage: message,
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && state.feedback == VoiceAssistantState.success) reset();
    });
  }
  
  void _cleanupAfterCommand() {
    final player = _ref.read(playerProvider.notifier);
    player.setVolume(1.0); // Restore volume
  }

  Future<void> _handleFinalResult(String text) async {
    if (state.feedback == VoiceAssistantState.processing) return;

    state = state.copyWith(
      feedback: VoiceAssistantState.processing,
      feedbackMessage: 'Processing…',
      recognizedText: text,
    );

    final playerState = _ref.read(playerProvider);
    final sessionCtx = _ref.read(sessionContextProvider);
    final currentTrack = playerState.currentTrack;

    try {
      final command = await _parser.parse(
        text,
        currentSongTitle: currentTrack?.title,
        currentArtist: currentTrack?.artist,
        sessionHistory: sessionCtx.recentSongIds,
        sessionArtists: sessionCtx.recentArtists,
      ).timeout(const Duration(seconds: 8));

      await _executeCommand(command);
    } catch (e) {
      _setError("Couldn't process that. Try again.");
    }
  }

  Future<void> _executeCommand(VoiceCommand command) async {
    final player = _ref.read(playerProvider.notifier);
    final sessionNotifier = _ref.read(sessionContextProvider.notifier);

    state = state.copyWith(feedback: VoiceAssistantState.executing);

    try {
      switch (command.intent) {
        case VoiceIntent.play:
        case VoiceIntent.pause:
          await player.togglePlayPause();
          _setSuccess(command.explanation ?? 'Done');

        case VoiceIntent.stop:
          await player.togglePlayPause();
          _setSuccess('Stopped');

        case VoiceIntent.next:
          await player.playNext();
          _setSuccess('Skipping to next song');

        case VoiceIntent.previous:
          await player.playPrevious();
          _setSuccess('Going to previous song');

        case VoiceIntent.volumeUp:
          _setSuccess('Volume increased (use system controls)');

        case VoiceIntent.volumeDown:
          _setSuccess('Volume decreased (use system controls)');

        case VoiceIntent.setVolume:
          _setSuccess('Set volume to ${command.volumePercent}% (use system controls)');

        case VoiceIntent.clearQueue:
          _setSuccess('Queue cleared is not supported yet');

        case VoiceIntent.addToQueue:
          final current = _ref.read(playerProvider).currentTrack;
          if (current != null) {
            await player.addToQueue(current);
            _setSuccess('Added "${current.title}" to queue');
          } else {
            _setError('Nothing is playing to queue');
          }

        case VoiceIntent.openSearch:
        case VoiceIntent.openLikedSongs:
        case VoiceIntent.openPlaylists:
        case VoiceIntent.openHome:
        case VoiceIntent.openLibrary:
          final msg = command.explanation ?? 'Navigating…';
          _setSuccess(msg);

        case VoiceIntent.searchAndPlay:
          final query = command.query ?? '';
          if (query.isEmpty) {
            _setError('What would you like to play?');
            return;
          }
          final tracks = await _musicService.search(query);
          if (tracks.isEmpty) {
            _setError('No results found for "$query"');
            return;
          }
          await player.playTrack(tracks.first, context: tracks.take(10).toList());
          _setSuccess('Playing "${tracks.first.title}"');

        case VoiceIntent.recommendation:
          sessionNotifier.setMoodOverride(command.mood, command.energy);

          if (command.suggestedSongs != null && command.suggestedSongs!.isNotEmpty) {
            _setSuccess('Generating AI playlist for ${command.mood ?? "you"}...');
            final List<Track> aiTracks = [];
            for (final song in command.suggestedSongs!) {
              final q = '${song["title"]} ${song["artist"]}';
              final res = await _musicService.search(q);
              if (res.isNotEmpty) aiTracks.add(res.first);
            }
            if (aiTracks.isNotEmpty) {
              await player.playTrack(aiTracks.first, context: aiTracks);
            }
          } else {
            _setSuccess(command.explanation ?? 'Applying ${command.mood} mood');
          }
          
        case VoiceIntent.chat:
          _setSuccess(command.chatResponse ?? 'I am here to help!');

        case VoiceIntent.unknown:
          _setError(command.explanation ?? "Sorry, I didn't catch that.");
      }
    } catch (e) {
      _setError('Error executing command: $e');
    }
  }
}

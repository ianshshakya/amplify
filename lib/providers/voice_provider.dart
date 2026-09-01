import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/voice_command.dart';
import '../providers/player_provider.dart';
import '../providers/recommendation_provider.dart';
import '../providers/session_context_provider.dart';
import '../providers/julu_provider.dart';
import '../services/voice_service.dart';
import '../services/voice_command_parser.dart';
import '../services/music_service.dart';

/// UI feedback state that the voice overlay displays to the user.
enum VoiceFeedback {
  idle,        // Mic button available, not active
  listening,   // Currently recording audio
  processing,  // Running command through parser / network
  success,     // Command executed successfully
  error,       // Something went wrong
}

@immutable
class VoiceState {
  final VoiceFeedback feedback;
  final String recognizedText;
  final String feedbackMessage;
  final VoiceCommand? lastCommand;

  const VoiceState({
    this.feedback = VoiceFeedback.idle,
    this.recognizedText = '',
    this.feedbackMessage = '',
    this.lastCommand,
  });

  VoiceState copyWith({
    VoiceFeedback? feedback,
    String? recognizedText,
    String? feedbackMessage,
    VoiceCommand? lastCommand,
  }) =>
      VoiceState(
        feedback: feedback ?? this.feedback,
        recognizedText: recognizedText ?? this.recognizedText,
        feedbackMessage: feedbackMessage ?? this.feedbackMessage,
        lastCommand: lastCommand ?? this.lastCommand,
      );
}

/// Orchestrates the full voice control flow:
///   Mic tap → VoiceService (STT) → VoiceCommandParser → PlayerNotifier action
///
/// Does NOT contain business logic — delegates everything to services/providers.
class VoiceNotifier extends StateNotifier<VoiceState> {
  final Ref _ref;
  final VoiceService _voiceService = VoiceService();
  final VoiceCommandParser _parser = VoiceCommandParser();
  final MusicService _musicService = MusicService();

  VoiceNotifier(this._ref) : super(const VoiceState());

  // ─── Public API ────────────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (state.feedback == VoiceFeedback.listening) return;

    state = const VoiceState(
      feedback: VoiceFeedback.listening,
      feedbackMessage: 'Listening…',
    );

    String recognized = '';

    final started = await _voiceService.startListening(
      onResult: (text, isFinal) {
        recognized = text;
        state = state.copyWith(recognizedText: text);
        if (isFinal && text.isNotEmpty) {
          _handleFinalResult(text);
        }
      },
      onDone: () {
        if (state.feedback == VoiceFeedback.listening) {
          // STT ended without a final result (silence / timeout)
          if (recognized.isEmpty) {
            _setError("Didn't hear anything — try again.");
          } else {
            _handleFinalResult(recognized);
          }
        }
      },
    );

    if (!started) {
      _setError('Microphone unavailable. Check permissions.');
    }
  }

  Future<void> stopListening() async {
    if (state.feedback != VoiceFeedback.listening) return;
    await _voiceService.stopListening();
    
    // Force immediate processing if we have text, otherwise show error.
    if (state.recognizedText.isNotEmpty) {
      _handleFinalResult(state.recognizedText);
    } else {
      _setError("Didn't hear anything — try again.");
    }
  }

  Future<void> toggleListening() async {
    if (state.feedback == VoiceFeedback.listening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  void reset() {
    state = const VoiceState();
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  Future<void> _handleFinalResult(String text) async {
    if (state.feedback == VoiceFeedback.processing) return; // already processing

    state = state.copyWith(
      feedback: VoiceFeedback.processing,
      feedbackMessage: 'Processing…',
      recognizedText: text,
    );

    // Log the user's message to Julu's chat history
    _ref.read(juluProvider.notifier).addUserMessage(text);

    // Get context so the parser can handle "something like this"
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

    try {
      switch (command.intent) {
        case VoiceIntent.play:
        case VoiceIntent.pause:
          await player.togglePlayPause();
          _setSuccess(command.explanation ?? 'Done');

        case VoiceIntent.stop:
          await player.togglePlayPause();
          _setSuccess('Stopped');
          _ref.read(juluProvider.notifier).addJuluMessage('I have stopped the music.');

        case VoiceIntent.next:
          await player.playNext();
          _setSuccess('Skipping to next song');

        case VoiceIntent.previous:
          await player.playPrevious();
          _setSuccess('Going to previous song');

        case VoiceIntent.volumeUp:
          // just_audio does not expose device volume — show feedback only
          _setSuccess('Volume increased (use system controls)');

        case VoiceIntent.volumeDown:
          _setSuccess('Volume decreased (use system controls)');

        case VoiceIntent.setVolume:
          _setSuccess('Set volume to ${command.volumePercent}% (use system controls)');

        case VoiceIntent.clearQueue:
          // Not directly exposed — we'll navigate; inform user
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
          // Navigation is handled by UI layer listening to lastCommand
          final msg = command.explanation ?? 'Navigating…';
          state = state.copyWith(
            feedback: VoiceFeedback.success,
            feedbackMessage: msg,
            lastCommand: command,
          );
          _ref.read(juluProvider.notifier).addJuluMessage(msg);

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
          // Apply mood/energy to session so the autoplay engine picks it up
          sessionNotifier.setMoodOverride(command.mood, command.energy);

          // If Groq provided specific AI-curated songs, search for them!
          if (command.suggestedSongs != null && command.suggestedSongs!.isNotEmpty) {
            _setSuccess('Generating AI playlist for ${command.mood ?? "you"}...');
            final List<Track> aiTracks = [];
            
            // Search for all suggested songs concurrently for speed
            final futures = command.suggestedSongs!.map((song) async {
              final q = '${song['title']} ${song['artist']}';
              final tracks = await _musicService.search(q);
              if (tracks.isNotEmpty) return tracks.first;
              return null;
            });
            
            final results = await Future.wait(futures);
            aiTracks.addAll(results.whereType<Track>());

            if (aiTracks.isNotEmpty) {
              await player.playTrack(aiTracks.first, context: aiTracks);
              final msg = 'I found some great songs for you. Playing ${command.mood ?? "your playlist"} now!';
              _setSuccess('Playing AI Curated Playlist');
              _ref.read(juluProvider.notifier).addJuluMessage(msg);
              return;
            }
          }

          // Fallback if no suggested songs (or if searches failed)
          final currentTrack = _ref.read(playerProvider).currentTrack;
          if (currentTrack != null) {
            final nextTracks = await _musicService.getNextTracks(
              currentTrack,
              _ref.read(sessionContextProvider),
            );
            if (nextTracks.isNotEmpty) {
              await player.playTrack(nextTracks.first, context: nextTracks.toList());
              final moodLabel = command.mood ?? command.energy ?? 'requested';
              _setSuccess('Playing $moodLabel music');
            } else {
              _setError('Could not find songs for that mood right now');
            }
          } else {
            // Nothing playing — use intelligent playlist generation
            final query = command.mood ?? command.energy ?? 'popular';
            final tracks = await _musicService.generatePlaylist(query);
            if (tracks.isNotEmpty) {
              await player.playTrack(tracks.first, context: tracks.toList());
              _setSuccess('Playing $query music');
            } else {
              _setError('Could not generate a playlist for that right now');
              _ref.read(juluProvider.notifier).addJuluMessage('Sorry, I could not generate a playlist for that right now.');
            }
          }

        case VoiceIntent.chat:
          final response = command.chatResponse ?? command.explanation ?? "I'm not sure how to respond to that.";
          _setSuccess(response);
          _ref.read(juluProvider.notifier).addJuluMessage(response);

        case VoiceIntent.unknown:
          final msg = command.explanation ?? 'Could not understand that';
          _setError(msg);
          _ref.read(juluProvider.notifier).addJuluMessage(msg);
      }
    } catch (e) {
      debugPrint('[VoiceProvider] Command execution error: $e');
      _setError('Something went wrong — try again');
    }
  }

  void _setSuccess(String message) {
    state = state.copyWith(
      feedback: VoiceFeedback.success,
      feedbackMessage: message,
    );
  }

  void _setError(String message) {
    state = state.copyWith(
      feedback: VoiceFeedback.error,
      feedbackMessage: message,
    );
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>(
  (ref) => VoiceNotifier(ref),
);

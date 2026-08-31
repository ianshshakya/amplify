import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Possible states of the voice recognition lifecycle.
enum VoiceListenState { idle, listening, done, error }

/// Thin wrapper around `speech_to_text` that handles:
/// - Microphone permission requests
/// - Push-to-talk start / stop
/// - Error handling (permission denied, STT unavailable, timeout, silence)
///
/// This service does NOT interpret commands. It only does Speech → Text.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _initialized = false;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Requests microphone permission and initializes the STT engine.
  /// Returns true if everything is ready.
  Future<bool> initialize() async {
    if (_initialized) return true;

    // 1. Check/request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('[VoiceService] Microphone permission denied: $status');
      return false;
    }

    // 2. Initialize the platform STT engine
    try {
      _initialized = await _stt.initialize(
        onError: (error) => debugPrint('[VoiceService] STT error: ${error.errorMsg}'),
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('[VoiceService] STT init failed: $e');
      _initialized = false;
    }

    return _initialized;
  }

  /// Whether the STT engine is currently recording audio.
  bool get isListening => _stt.isListening;

  /// Whether the STT engine is ready to use (initialized and not already listening).
  bool get isAvailable => _initialized && _stt.isAvailable;

  /// Start listening. [onResult] is called every time the STT engine has a
  /// partial or final transcription. [onDone] is called when listening stops.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_stt.isListening) return false;

    try {
      await _stt.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 2),
          cancelOnError: true,
          partialResults: true,
          onDevice: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceService] startListening error: $e');
      return false;
    }
  }

  /// Stop listening early (e.g. user releases the button).
  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  /// Cancel and discard any in-progress recognition.
  Future<void> cancel() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
  }

  /// Returns true if the device has a working STT engine available.
  Future<bool> checkAvailability() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) return false;
    if (!_initialized) await initialize();
    return _initialized;
  }
}

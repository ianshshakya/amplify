import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class WakeWordService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.amplify/wake_word');
  static const EventChannel _eventChannel = EventChannel('com.example.amplify/wake_word_events');

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  Stream<void>? _wakeWordStream;

  /// Subscribe to this stream to get notified when "Hey Bingo" is heard
  Stream<void> get wakeWordDetected {
    _wakeWordStream ??= _eventChannel.receiveBroadcastStream().where((event) {
      if (event == "WAKE_WORD_DETECTED") return true;
      if (event == "WAKE_WORD_ERROR") {
        debugPrint("[WakeWordService] Error received from native.");
      }
      return false;
    }).map((_) => null);
    return _wakeWordStream!;
  }

  Future<void> initialize() async {
    // Basic setup if required
  }

  /// Start the background foreground service
  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      final success = await _methodChannel.invokeMethod<bool>('startService');

      if (success == true) {
        _isRunning = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("[WakeWordService] Failed to start native service: $e");
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await _methodChannel.invokeMethod('stopService');
      _isRunning = false;
    } catch (e) {
      debugPrint("[WakeWordService] Failed to stop native service: $e");
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}

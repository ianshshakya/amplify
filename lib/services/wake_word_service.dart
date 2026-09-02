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
      if (event == "WAKE_WORD_DETECTED") {
        _isRunning = false; // Native side automatically stopped
        return true;
      }
      if (event == "WAKE_WORD_ERROR") {
        _isRunning = false;
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
    // We always attempt to invoke the method to ensure native sync

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

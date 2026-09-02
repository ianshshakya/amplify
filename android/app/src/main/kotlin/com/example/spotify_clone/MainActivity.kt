package com.example.spotify_clone

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService

class MainActivity : AudioServiceActivity(), RecognitionListener {
    private val METHOD_CHANNEL = "com.example.amplify/wake_word"
    private val EVENT_CHANNEL = "com.example.amplify/wake_word_events"
    
    private var eventSink: EventChannel.EventSink? = null
    
    private var model: Model? = null
    private var speechService: SpeechService? = null
    private var isListening = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    initModel()
                    result.success(true)
                }
                "stopService" -> {
                    stopRecognition()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun initModel() {
        if (model != null) {
            startRecognition()
            return
        }

        StorageService.unpack(this, "model", "model",
            { m ->
                model = m
                startRecognition()
            },
            { e ->
                Log.e("MainActivity", "Failed to unpack model", e)
                eventSink?.error("WAKE_WORD_ERROR", "Failed to unpack model: ${e.message}", null)
            }
        )
    }

    private fun startRecognition() {
        if (speechService != null || isListening) return

        try {
            val recognizer = Recognizer(model, 16000.0f)
            speechService = SpeechService(recognizer, 16000.0f)
            speechService?.startListening(this)
            isListening = true
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to start recognition", e)
            eventSink?.error("WAKE_WORD_ERROR", "Failed to start engine: ${e.message}", null)
            stopRecognition()
        }
    }

    private fun stopRecognition() {
        isListening = false
        // stop() can block if it waits for the audio thread. 
        // Run it in a background thread to prevent freezing the UI.
        val currentService = speechService
        speechService = null
        
        Thread {
            try {
                currentService?.stop()
                currentService?.shutdown()
            } catch (e: Exception) {
                Log.e("MainActivity", "Error stopping speech service", e)
            }
        }.start()
    }

    override fun onPartialResult(hypothesis: String?) {
        if (hypothesis != null && hypothesis.contains("hey bingo", ignoreCase = true)) {
            Log.d("MainActivity", "Wake word detected!")
            triggerHapticFeedback()
            
            // Stop listening immediately to release the microphone for Flutter/just_audio
            stopRecognition()
            
            // Notify Flutter
            eventSink?.success("WAKE_WORD_DETECTED")
        }
    }

    private fun triggerHapticFeedback() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(60, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(60)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to vibrate", e)
        }
    }

    override fun onResult(hypothesis: String?) {}
    override fun onFinalResult(hypothesis: String?) {}
    override fun onError(e: Exception?) {
        Log.e("MainActivity", "Recognition Error", e)
        eventSink?.error("WAKE_WORD_ERROR", "Recognition Error", null)
    }
    override fun onTimeout() {}

    override fun onDestroy() {
        super.onDestroy()
        stopRecognition()
    }
}

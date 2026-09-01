package com.example.spotify_clone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService

class WakeWordService : Service(), RecognitionListener {
    private val CHANNEL_ID = "WakeWordServiceChannel"
    
    private var model: Model? = null
    private var speechService: SpeechService? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Notification.Builder(this, CHANNEL_ID)
                        .setContentTitle("Amplify Hands-Free")
                        .setContentText("Listening for Hey Bingo")
                        .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                        .build()
                } else {
                    Notification.Builder(this)
                        .setContentTitle("Amplify Hands-Free")
                        .setContentText("Listening for Hey Bingo")
                        .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                        .build()
                }
                startForeground(1, notification)
                initModel()
            }
            "STOP" -> {
                stopSelf()
            }
        }
        return START_STICKY
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
                Log.e("WakeWordService", "Failed to unpack model", e)
                sendErrorEvent("Failed to unpack model: ${e.message}")
                stopSelf()
            }
        )
    }

    private fun startRecognition() {
        if (speechService != null) return

        try {
            val recognizer = Recognizer(model, 16000.0f)
            speechService = SpeechService(recognizer, 16000.0f)
            speechService?.startListening(this)
        } catch (e: Exception) {
            Log.e("WakeWordService", "Failed to start recognition", e)
            sendErrorEvent("Failed to start engine: ${e.message}")
            stopSelf()
        }
    }

    override fun onPartialResult(hypothesis: String?) {
        if (hypothesis != null && hypothesis.contains("hey bingo", ignoreCase = true)) {
            Log.d("WakeWordService", "Wake word detected!")
            triggerHapticFeedback()
            sendDetectionEvent()
            
            // Stop listening momentarily to prevent duplicate triggers
            // The Dart side will call startService again when it's ready to resume listening
            speechService?.stop()
            speechService = null
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
            Log.e("WakeWordService", "Failed to vibrate", e)
        }
    }

    override fun onResult(hypothesis: String?) {
        // We catch it in onPartialResult for faster response
    }

    override fun onFinalResult(hypothesis: String?) {
    }

    override fun onError(e: Exception?) {
        Log.e("WakeWordService", "Recognition Error", e)
    }

    override fun onTimeout() {
    }

    private fun sendDetectionEvent() {
        val intent = Intent("WAKE_WORD_DETECTED")
        sendBroadcast(intent)
    }

    private fun sendErrorEvent(message: String) {
        val intent = Intent("WAKE_WORD_ERROR").apply {
            putExtra("error", message)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            speechService?.stop()
            speechService?.shutdown()
            speechService = null
        } catch (e: Exception) {
            Log.e("WakeWordService", "Error shutting down speech service", e)
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Hands-Free Wake Word",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Runs the microphone listening engine"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }
}

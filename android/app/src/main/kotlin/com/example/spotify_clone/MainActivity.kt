package com.example.spotify_clone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private val METHOD_CHANNEL = "com.example.amplify/wake_word"
    private val EVENT_CHANNEL = "com.example.amplify/wake_word_events"
    
    private var eventSink: EventChannel.EventSink? = null

    private val wakeWordReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "WAKE_WORD_DETECTED") {
                eventSink?.success("WAKE_WORD_DETECTED")
            } else if (intent?.action == "WAKE_WORD_ERROR") {
                val errorMsg = intent.getStringExtra("error") ?: "Unknown error"
                eventSink?.error("WAKE_WORD_ERROR", errorMsg, null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, WakeWordService::class.java).apply {
                        action = "START"
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    val intent = Intent(this, WakeWordService::class.java).apply {
                        action = "STOP"
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    val filter = IntentFilter().apply {
                        addAction("WAKE_WORD_DETECTED")
                        addAction("WAKE_WORD_ERROR")
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(wakeWordReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(wakeWordReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    try {
                        unregisterReceiver(wakeWordReceiver)
                    } catch (e: Exception) {
                        // Ignore if not registered
                    }
                }
            }
        )
    }
}

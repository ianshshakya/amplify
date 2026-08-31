# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Audio Service & Just Audio Background
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

# Ignore missing Play Core classes referenced by Flutter's deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

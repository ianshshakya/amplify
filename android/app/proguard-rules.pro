# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Just Audio Background
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keep class androidx.media3.session.** { *; }
-keep class androidx.media3.extractor.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.ryanheise.audio_service.** { *; }

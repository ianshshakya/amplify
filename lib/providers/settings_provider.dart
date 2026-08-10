import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudioQuality { low, medium, high }

@immutable
class AppSettings {
  final ThemeMode themeMode;
  final AudioQuality audioQuality;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.audioQuality = AudioQuality.high,
  });

  AppSettings copyWith({ThemeMode? themeMode, AudioQuality? audioQuality}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        audioQuality: audioQuality ?? this.audioQuality,
      );

  String get qualityLabel => switch (audioQuality) {
        AudioQuality.low => '128 kbps',
        AudioQuality.medium => '256 kbps',
        AudioQuality.high => 'Best available',
      };
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0=dark,1=light,2=system
    final qualityIndex = prefs.getInt('audio_quality') ?? 2;
    state = AppSettings(
      themeMode: ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)],
      audioQuality: AudioQuality.values[qualityIndex.clamp(0, AudioQuality.values.length - 1)],
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setAudioQuality(AudioQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('audio_quality', quality.index);
    state = state.copyWith(audioQuality: quality);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

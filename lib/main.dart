import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'providers/settings_provider.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enables audio to keep playing when the app is backgrounded and shows
  // playback controls in the notification shade / lock screen.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.spotify_clone.channel.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  runApp(
    // ProviderScope is the Riverpod equivalent of MultiProvider —
    // it must wrap the entire widget tree.
    const ProviderScope(child: AmplifyApp()),
  );
}

class AmplifyApp extends ConsumerWidget {
  const AmplifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings so theme changes apply immediately.
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Amplify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const AuthGate(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'providers/settings_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/ask_julu_screen.dart';
import 'services/notification_service.dart';
import 'providers/voice_provider.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    // ProviderScope is the Riverpod equivalent of MultiProvider
    const ProviderScope(child: AmplifyApp()),
  );
}

class AmplifyApp extends ConsumerStatefulWidget {
  const AmplifyApp({super.key});

  @override
  ConsumerState<AmplifyApp> createState() => _AmplifyAppState();
}

class _AmplifyAppState extends ConsumerState<AmplifyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notification service and handle taps
    NotificationService().initialize((payload) {
      if (payload == 'julu_voice') {
        _handleJuluNotification();
      }
    });

    // Show the persistent notification
    NotificationService().showJuluPersistentNotification();
  }

  void _handleJuluNotification() {
    // Navigate to Ask Julu Screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const AskJuluScreen()),
    );
    // Start listening instantly
    ref.read(voiceProvider.notifier).startListening();
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings so theme changes apply immediately.
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Amplify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const AuthGate(),
    );
  }
}



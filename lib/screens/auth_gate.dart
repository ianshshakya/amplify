import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import 'login_screen.dart';
import 'root_shell.dart';
import 'splash_transition.dart';
import '../services/api_client.dart';

/// Entry point that watches auth state and routes to login or main shell.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Kick off auth check on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    final isReady = auth.status != AuthStatus.checking;

    Widget child = switch (auth.status) {
      AuthStatus.checking => const Scaffold(backgroundColor: Colors.black),
      AuthStatus.loggedOut => const LoginScreen(),
      AuthStatus.loggedIn => _LoggedInShell(),
    };

    return CinematicSplashOverlay(
      isReady: isReady,
      child: child,
    );
  }
}

/// Triggers user data loading once on login, then shows the root shell.
class _LoggedInShell extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LoggedInShell> createState() => _LoggedInShellState();
}

class _LoggedInShellState extends ConsumerState<_LoggedInShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playlistProvider.notifier).loadUserData();
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      final res = await ApiClient().get('/app/config');
      final latestVersion = res['latestVersion'] as String?;
      final downloadUrl = res['downloadUrl'] as String?;
      
      const currentVersion = '1.0.0'; 
      if (latestVersion != null && latestVersion != currentVersion && downloadUrl != null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Update Available', style: TextStyle(color: Colors.white)),
            content: Text('A new version ($latestVersion) of Amplify is available! You can download it from our website.', style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Visit: $downloadUrl to download'),
                      duration: const Duration(seconds: 10),
                    ),
                  );
                },
                child: const Text('Update', style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => const RootShell();
}

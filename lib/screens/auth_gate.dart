import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import 'login_screen.dart';
import 'root_shell.dart';

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

    return switch (auth.status) {
      AuthStatus.checking => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.loggedOut => const LoginScreen(),
      AuthStatus.loggedIn => _LoggedInShell(),
    };
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
    });
  }

  @override
  Widget build(BuildContext context) => const RootShell();
}

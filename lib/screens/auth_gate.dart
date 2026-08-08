import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'root_shell.dart';

/// Shown first at app launch. Checks whether a saved token is still
/// valid, then routes to either the logged-in app shell or the login
/// screen — so returning users skip the login form entirely.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    await auth.checkAuthState();

    if (auth.status == AuthStatus.loggedIn && mounted) {
      await context.read<PlaylistProvider>().loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.checking:
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        );
      case AuthStatus.loggedIn:
        return const RootShell();
      case AuthStatus.loggedOut:
        return const LoginScreen();
    }
  }
}

// lib/screens/import/bring_your_music_screen.dart
// "Bring Your Music" — entry point for the Universal Music Import feature.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/import_provider.dart';
import '../../models/import_models.dart';
import '../../services/import_service.dart';
import 'import_progress_screen.dart';

class BringYourMusicScreen extends ConsumerStatefulWidget {
  const BringYourMusicScreen({super.key});

  @override
  ConsumerState<BringYourMusicScreen> createState() => _BringYourMusicScreenState();
}

class _BringYourMusicScreenState extends ConsumerState<BringYourMusicScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  bool _isConnecting = false;
  String? _connectingProvider;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _connectProvider(String provider) async {
    if (_isConnecting) return;
    setState(() { _isConnecting = true; _connectingProvider = provider; });

    try {
      final res = await ImportService().initiateOAuth(provider);
      final authUrl = res['authUrl'] as String?;
      if (authUrl == null) throw Exception('No auth URL received');

      final uri = Uri.parse(authUrl);
      if (!await canLaunchUrl(uri)) throw Exception('Could not open browser');

      // Open the browser — user authorizes, Google redirects to our backend
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // Poll the backend every 2s until the service appears (max 90s)
      final providerName = provider == 'youtube' ? 'YouTube Music' : 'Spotify';
      bool connected = false;
      for (int i = 0; i < 45; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        try {
          final services = await ImportService().getConnectedServices();
          if (services.any((s) => (s as Map)['provider'] == provider)) {
            connected = true;
            break;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      ref.invalidate(connectedServicesProvider);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(connected
            ? '$providerName connected successfully!'
            : 'Connection timed out. Did you complete authorization in the browser?'),
        backgroundColor: connected ? AppColors.primary : AppColors.warning,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() { _isConnecting = false; _connectingProvider = null; });
    }
  }

  Future<void> _startImport(String provider) async {
    setState(() { _isConnecting = true; _connectingProvider = provider; });
    try {
      final jobId = await ref.read(activeImportJobProvider.notifier).startImport(provider);
      if (mounted && jobId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImportProgressScreen(jobId: jobId, provider: provider),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start import: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() { _isConnecting = false; _connectingProvider = null; });
    }
  }

  Future<void> _disconnect(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight,
        title: const Text('Disconnect?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Your imported playlists and library data will be preserved in Amplify.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disconnect', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(connectedServicesProvider.notifier).disconnect(provider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedAsync = ref.watch(connectedServicesProvider);
    final providersAsync = ref.watch(importProvidersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              backgroundColor: AppColors.background,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.8),
                        const Color(0xFF6A1B9A).withOpacity(0.7),
                        AppColors.background,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.library_music_rounded,
                            size: 44, color: Colors.white),
                          const SizedBox(height: 12),
                          const Text(
                            'Bring Your Music',
                            style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white,
                            ),
                          ),
                          Text(
                            'Move your playlists and library\nwithout rebuilding everything from scratch.',
                            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Connected Services
                    connectedAsync.when(
                      data: (services) {
                        if (services.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Connected'),
                            const SizedBox(height: 12),
                            ...services.map((s) => _connectedServiceTile(s)),
                            const SizedBox(height: 24),
                            _sectionTitle('Import Again'),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // Provider cards
                    providersAsync.when(
                      data: (providers) => Column(
                        children: providers.map((p) {
                          final isConnected = connectedAsync.value?.any((s) => s.provider == p.id) ?? false;
                          return _providerCard(p, isConnected);
                        }).toList(),
                      ),
                      loading: () => _skeletonCard(),
                      error: (e, _) => Center(
                        child: Text('Failed to load providers: $e',
                          style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Privacy notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Amplify imports your music library and playlists to recreate your listening experience. '
                              'We don\'t copy or download music from other services. '
                              'Your imported data improves personalized recommendations.',
                              style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12, height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerCard(ProviderInfo provider, bool isConnected) {
    final isThisConnecting = _isConnecting && _connectingProvider == provider.id;
    final isSpotify = provider.id == 'spotify';

    final cardColor = isSpotify
        ? const Color(0xFF1DB954).withOpacity(0.12)
        : Colors.red.withOpacity(0.10);
    final accentColor = isSpotify ? const Color(0xFF1DB954) : Colors.red;
    final icon = isSpotify ? Icons.music_note_rounded : Icons.play_circle_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? accentColor.withOpacity(0.5) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        if (isConnected)
                          Row(
                            children: [
                              Icon(Icons.check_circle, size: 12, color: accentColor),
                              const SizedBox(width: 4),
                              Text('Connected',
                                style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          )
                        else
                          Text('Not connected',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(provider.description,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),

              if (provider.limitation != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(provider.limitation!,
                        style: TextStyle(color: AppColors.warning, fontSize: 11)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              if (!provider.configured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${provider.name} integration not configured on this server.',
                    style: TextStyle(color: AppColors.warning, fontSize: 11),
                  ),
                )
              else
                Row(
                  children: [
                    if (!isConnected)
                      Expanded(
                        child: _actionButton(
                          label: 'Connect ${provider.name}',
                          icon: Icons.link_rounded,
                          color: accentColor,
                          loading: isThisConnecting,
                          onTap: () => _connectProvider(provider.id),
                        ),
                      ),
                    if (isConnected) ...[
                      Expanded(
                        child: _actionButton(
                          label: 'Import Library',
                          icon: Icons.download_for_offline_rounded,
                          color: AppColors.primary,
                          loading: isThisConnecting,
                          onTap: () => _startImport(provider.id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.link_off_rounded, color: AppColors.textSecondary, size: 20),
                        tooltip: 'Disconnect',
                        onPressed: () => _disconnect(provider.id),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectedServiceTile(ConnectedService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.provider.capitalize(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                if (service.displayName != null)
                  Text(service.displayName!,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _disconnect(service.provider),
            child: Text('Disconnect', style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        onPressed: loading ? null : onTap,
        icon: loading
          ? SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color))
          : Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title.toUpperCase(),
    style: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    ),
  );

  Widget _skeletonCard() => Container(
    height: 160,
    decoration: BoxDecoration(
      color: AppColors.surfaceHighlight,
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

extension _StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

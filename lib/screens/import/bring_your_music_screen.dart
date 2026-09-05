// lib/screens/import/bring_your_music_screen.dart
// "Bring Your Music" — entry point for the Universal Music Import feature.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/import_provider.dart';
import '../../models/import_models.dart';
import '../../services/import_service.dart';
import 'import_progress_screen.dart';
import 'spotify_export_guide_screen.dart';

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

  Future<void> _pickAndUploadSpotifyExport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() { _isConnecting = true; _connectingProvider = 'spotify'; });
        
        final filePath = result.files.single.path!;
        final res = await ImportService().uploadSpotifyExport(filePath);
        
        if (mounted && res['importJobId'] != null) {
          final jobId = res['importJobId'] as String;
          // Start polling for this newly created job
          ref.read(activeImportJobProvider.notifier).resumePolling(jobId);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImportProgressScreen(jobId: jobId, provider: 'spotify'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
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
              expandedHeight: 280,
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Glowing Orbs
                    Positioned(
                      top: -40,
                      right: -60,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.4),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 100, spreadRadius: 50),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -80,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6A1B9A).withOpacity(0.3),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF6A1B9A).withOpacity(0.4), blurRadius: 120, spreadRadius: 40),
                          ],
                        ),
                      ),
                    ),
                    // Glass Overlay
                    ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.1),
                                AppColors.background,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Icon(Icons.library_music_rounded,
                                size: 36, color: Colors.white),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Bring Your Music',
                              style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Move your playlists and library\nwithout rebuilding everything from scratch.',
                              style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7), height: 1.4),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                    
                    const SizedBox(height: 16),
                    
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SpotifyExportGuideScreen()));
                        },
                        icon: const Icon(Icons.help_outline),
                        label: const Text('How to get your Spotify data'),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isConnected ? accentColor.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 12, spreadRadius: 2),
                          ],
                        ),
                        child: Icon(icon, color: accentColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(provider.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
                            const SizedBox(height: 4),
                            if (isConnected)
                              Row(
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Text('Connected',
                                    style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              )
                            else
                              Text('Not connected',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(provider.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5)),

                  if (provider.limitation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(provider.limitation!,
                              style: TextStyle(color: AppColors.warning, fontSize: 12, height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  if (provider.id == 'spotify')
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            label: 'Upload Export (ZIP)',
                            icon: Icons.upload_file_rounded,
                            color: accentColor,
                            loading: isThisConnecting,
                            onTap: _pickAndUploadSpotifyExport,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    )
                  else if (!provider.configured)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.name} integration not configured on this server.',
                        style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500),
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
                              isPrimary: true,
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
                              isPrimary: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.link_off_rounded, color: Colors.white.withOpacity(0.6), size: 22),
                              tooltip: 'Disconnect',
                              onPressed: () => _disconnect(provider.id),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectedServiceTile(ConnectedService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.provider.capitalize(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                if (service.displayName != null) ...[
                  const SizedBox(height: 2),
                  Text(service.displayName!,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                ]
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: AppColors.error.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _disconnect(service.provider),
            child: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
    bool isPrimary = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isPrimary ? LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        color: isPrimary ? null : color.withOpacity(0.15),
        boxShadow: isPrimary ? [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: loading ? null : onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: isPrimary ? Colors.white : color))
              else
                Icon(icon, size: 20, color: isPrimary ? Colors.white : color),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : color,
                letterSpacing: 0.2,
              )),
            ],
          ),
        ),
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

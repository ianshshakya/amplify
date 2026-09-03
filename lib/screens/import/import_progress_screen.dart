// lib/screens/import/import_progress_screen.dart
// Live import progress screen. Polls job status and shows animated progress.
// The user can navigate away — the import continues in the background.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/import_models.dart';
import '../../providers/import_provider.dart';
import 'import_results_screen.dart';
import 'import_review_screen.dart';

class ImportProgressScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String provider;

  const ImportProgressScreen({
    super.key,
    required this.jobId,
    required this.provider,
  });

  @override
  ConsumerState<ImportProgressScreen> createState() => _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Resume polling in case we navigated back to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeImportJobProvider.notifier).resumePolling(widget.jobId);
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onJobFinished(ImportJob job) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ImportResultsScreen(jobId: job.id, provider: job.provider)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(activeImportJobProvider);

    // Navigate to results when done
    if (job != null && job.status.isFinished) {
      _onJobFinished(job);
    }

    final progress = job?.progress ?? 0.0;
    final providerName = widget.provider == 'spotify' ? 'Spotify' : 'YouTube Music';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () {
            // Let them navigate away — polling continues
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surfaceHighlight,
                title: const Text('Import Running', style: TextStyle(color: Colors.white)),
                content: Text(
                  'Your import is continuing in the background. Go to Library → Import History to check progress.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                    child: const Text('Leave'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Stay', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text('Importing from $providerName',
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // Animated icon
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (_, child) {
                return Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.3),
                      ],
                      transform: GradientRotation(_shimmerController.value * 6.28),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.library_music_rounded, color: Colors.white, size: 48),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            Text(
              job?.status.label ?? 'Starting…',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (job != null && job.totalItems > 0)
              Text(
                '${job.processedItems.toLocale()} / ${job.totalItems.toLocale()} tracks',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),

            const SizedBox(height: 32),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null, // indeterminate if no progress
                minHeight: 10,
                backgroundColor: AppColors.surfaceHighlight,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),

            if (job != null && job.totalItems > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],

            const SizedBox(height: 40),

            // Stats grid
            if (job != null)
              _statsGrid(job),

            const Spacer(),

            // Background note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Import continues in the background. You can leave this screen.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Cancel button
            TextButton(
              onPressed: () async {
                await ref.read(activeImportJobProvider.notifier).cancel();
                if (mounted) Navigator.pop(context);
              },
              child: Text('Cancel Import', style: TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(ImportJob job) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statTile(
          icon: Icons.check_circle_rounded,
          label: 'Matched',
          value: job.matchedItems.toLocale(),
          color: AppColors.primary,
        ),
        _statTile(
          icon: Icons.queue_music_rounded,
          label: 'Playlists',
          value: job.playlistsImported.toLocale(),
          color: const Color(0xFF6A1B9A),
        ),
        _statTile(
          icon: Icons.rate_review_rounded,
          label: 'Need Review',
          value: job.reviewItems.toLocale(),
          color: AppColors.warning,
        ),
        _statTile(
          icon: Icons.block_rounded,
          label: 'Unavailable',
          value: job.unavailableItems.toLocale(),
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

extension _IntFormat on int {
  String toLocale() {
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    if (this >= 1000) return '${(this / 1000).toStringAsFixed(1)}K';
    return toString();
  }
}

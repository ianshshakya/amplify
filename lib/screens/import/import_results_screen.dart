// lib/screens/import/import_results_screen.dart
// Post-import summary screen showing what was imported.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/import_models.dart';
import '../../services/import_service.dart';
import '../../providers/import_provider.dart';
import '../../providers/playlist_provider.dart';
import '../library_screen.dart';
import 'import_review_screen.dart';

class ImportResultsScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String provider;

  const ImportResultsScreen({super.key, required this.jobId, required this.provider});

  @override
  ConsumerState<ImportResultsScreen> createState() => _ImportResultsScreenState();
}

class _ImportResultsScreenState extends ConsumerState<ImportResultsScreen>
    with SingleTickerProviderStateMixin {
  ImportJob? _job;
  bool _loading = true;
  late AnimationController _entryController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideAnim = Tween(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _loadJob();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadJob() async {
    try {
      final raw = await ImportService().getJobStatus(widget.jobId);
      setState(() { _job = ImportJob.fromJson(raw); _loading = false; });
      _entryController.forward();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = widget.provider == 'spotify' ? 'Spotify' : 'YouTube Music';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // Success icon
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [AppColors.primary.withOpacity(0.4), Colors.transparent],
                            ),
                          ),
                          child: Icon(
                            _job?.status == ImportStatus.failed
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_rounded,
                            size: 56,
                            color: _job?.status == ImportStatus.failed
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          _job?.status == ImportStatus.failed
                              ? 'Import Failed'
                              : _job?.status == ImportStatus.partial
                                  ? 'Partially Imported'
                                  : 'Your music is ready.',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Imported from $providerName',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),

                        if (_job?.error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_job!.error!,
                              style: TextStyle(color: AppColors.error, fontSize: 12)),
                          ),
                        ],

                        const SizedBox(height: 36),

                        if (_job != null) _statsSection(_job!),

                        const SizedBox(height: 40),

                        // Action buttons
                        if (_job != null && _job!.reviewItems > 0)
                          _primaryButton(
                            label: 'Review ${_job!.reviewItems} Uncertain Matches',
                            icon: Icons.rate_review_rounded,
                            color: AppColors.warning,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ImportReviewScreen(jobId: widget.jobId),
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        _primaryButton(
                          label: 'View My Library',
                          icon: Icons.library_music_rounded,
                          color: AppColors.primary,
                          onTap: () {
                            ref.read(activeImportJobProvider.notifier).clear();
                            // Refresh the user's library and playlists from backend
                            ref.read(playlistProvider.notifier).loadUserData();
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _statsSection(ImportJob job) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _statRow(
            icon: Icons.library_music_rounded,
            label: 'Tracks found',
            value: job.totalItems.toString(),
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          _statRow(
            icon: Icons.check_circle_rounded,
            label: 'Matched',
            value: job.matchedItems.toString(),
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _statRow(
            icon: Icons.queue_music_rounded,
            label: 'Playlists imported',
            value: job.playlistsImported.toString(),
            color: const Color(0xFF6A1B9A),
          ),
          if (job.historyRecords > 0) ...[
            const SizedBox(height: 12),
            _statRow(
              icon: Icons.history_rounded,
              label: 'History records imported',
              value: job.historyRecords.toString(),
              color: Colors.blueAccent,
            ),
          ],
          if (job.reviewItems > 0) ...[
            const Divider(color: Colors.white12, height: 24),
            _statRow(
              icon: Icons.rate_review_rounded,
              label: 'Need review',
              value: job.reviewItems.toString(),
              color: AppColors.warning,
            ),
          ],
          if (job.unavailableItems > 0) ...[
            const SizedBox(height: 12),
            _statRow(
              icon: Icons.block_rounded,
              label: 'Unavailable in Amplify',
              value: job.unavailableItems.toString(),
              color: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

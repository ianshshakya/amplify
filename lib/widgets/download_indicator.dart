import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';

/// Shows the download status of a track as a compact icon button.
/// - idle: outline download icon
/// - downloading: circular progress indicator
/// - done: filled green check/download icon
/// - error: red error icon (tap to retry)
class DownloadIndicator extends ConsumerWidget {
  final Track track;

  const DownloadIndicator({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadProvider);
    final status = state.statusFor(track.videoId);
    final progress = state.progressFor(track.videoId);

    return switch (status) {
      DownloadStatus.idle => IconButton(
          icon: const Icon(Icons.download_outlined, size: 22),
          color: AppColors.textSecondary,
          tooltip: 'Download',
          onPressed: () => ref.read(downloadProvider.notifier).download(track),
        ),
      DownloadStatus.downloading => SizedBox(
          width: 40,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      DownloadStatus.done => IconButton(
          icon: const Icon(Icons.download_done, size: 22),
          color: Colors.green,
          tooltip: 'Downloaded - Tap to remove',
          onPressed: () => ref.read(downloadProvider.notifier).removeDownload(track.videoId),
        ),
      DownloadStatus.error => IconButton(
          icon: const Icon(Icons.error_outline, size: 22),
          color: AppColors.error,
          tooltip: 'Download failed — tap to retry',
          onPressed: () => ref.read(downloadProvider.notifier).download(track),
        ),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../screens/player_screen.dart';
import '../screens/artist_screen.dart';

/// The thin bar pinned above the bottom nav. Mirrors Spotify's mini player:
/// - Tapping opens the full PlayerScreen with a Hero art transition
/// - Swipe right → next track
/// - Swipe left → previous track
/// - Progress bar across the top
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const PlayerScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: AppDurations.medium,
        ),
      ),
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) {
          // Swipe left = next
          ref.read(playerProvider.notifier).playNext();
        } else if (details.primaryVelocity! > 300) {
          // Swipe right = previous
          ref.read(playerProvider.notifier).playPrevious();
        }
      },
      child: Material(
        color: AppColors.surfaceHighlight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            StreamBuilder<Duration>(
              stream: ref.read(playerProvider.notifier).positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = playerState.duration;
                final progress = total.inMilliseconds > 0
                    ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                );
              },
            ),

            // Content row
            SizedBox(
              height: 62,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Album art with Hero tag (matches PlayerScreen tag)
                    Hero(
                      tag: 'mini-player-art-${track.videoId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: track.thumbnailUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title & artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Controls: like, prev, play/pause, next
                    if (playerState.status == PlaybackStatus.loading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else if (playerState.status == PlaybackStatus.error)
                      IconButton(
                        icon: const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                        onPressed: () => ref.read(playerProvider.notifier).playTrack(track),
                      )
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 26),
                        padding: EdgeInsets.zero,
                        onPressed: () => ref.read(playerProvider.notifier).playPrevious(),
                      ),
                      IconButton(
                        icon: Icon(
                          playerState.status == PlaybackStatus.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 34,
                          color: AppColors.textPrimary,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 26),
                        padding: EdgeInsets.zero,
                        onPressed: () => ref.read(playerProvider.notifier).playNext(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

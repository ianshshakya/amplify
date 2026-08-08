import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart' as player_provider;
import '../providers/playlist_provider.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<player_provider.PlayerProvider>();
    final playlists = context.watch<PlaylistProvider>();
    final track = player.currentTrack;

    if (track == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    final isLiked = playlists.isLiked(track);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('NOW PLAYING', style: TextStyle(fontSize: 12)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: () => playlists.toggleLiked(track),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = player.duration;
                final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
                final valueMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);

                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: AppColors.primary,
                      ),
                      child: Slider(
                        min: 0,
                        max: maxMs,
                        value: valueMs,
                        onChanged: (value) {
                          player.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(_formatDuration(total),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: player.shuffleEnabled ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: player.toggleShuffle,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: player.playPrevious,
                ),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textPrimary,
                  ),
                  child: IconButton(
                    iconSize: 40,
                    color: Colors.black,
                    icon: player.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: player.togglePlayPause,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: player.playNext,
                ),
                IconButton(
                  icon: Icon(
                    player.repeatMode == player_provider.RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                    color: player.repeatMode == player_provider.RepeatMode.off
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                  onPressed: player.cycleRepeatMode,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

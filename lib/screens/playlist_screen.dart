import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';
import '../widgets/mini_player.dart';
import '../widgets/playlist_collage.dart';

/// Shows a single server-side playlist (created by the user) and its
/// tracks. For "Liked Songs" use LikedSongsScreen instead — that's a
/// separate flat list on the backend, not a playlist document.
class PlaylistScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistState = ref.watch(playlistProvider);
    final playlist = playlistState.playlists.firstWhere((p) => p.id == playlistId);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surfaceHighlight,
                  title: const Text('Delete playlist?'),
                  content: Text('Are you sure you want to delete "${playlist.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (context.mounted) {
                  Navigator.pop(context);
                  await ref.read(playlistProvider.notifier).deletePlaylist(playlistId);
                }
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                PlaylistCollage(
                  imageUrls: playlist.tracks.map((t) => t.thumbnailUrl).toList(),
                  width: 120,
                  height: 120,
                  borderRadius: 8,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${playlist.tracks.length} songs',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (playlist.tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      ref.read(playerProvider.notifier).playTrack(
                            playlist.tracks.first,
                            context: playlist.tracks,
                          );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: playlist.tracks.isEmpty
                ? const Center(
                    child: Text(
                      'No songs here yet.\nAdd songs from search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: playlist.tracks.length,
                    itemBuilder: (context, index) {
                      return TrackTile(
                        track: playlist.tracks[index],
                        context_: playlist.tracks,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

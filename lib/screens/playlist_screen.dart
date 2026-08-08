import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

/// Shows a single server-side playlist (created by the user) and its
/// tracks. For "Liked Songs" use LikedSongsScreen instead — that's a
/// separate flat list on the backend, not a playlist document.
class PlaylistScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final playlist = playlistProvider.playlists.firstWhere((p) => p.id == playlistId);

    return Scaffold(
      appBar: AppBar(title: Text(playlist.name)),
      body: Column(
        children: [
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
                      context.read<PlayerProvider>().playTrack(
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
    );
  }
}

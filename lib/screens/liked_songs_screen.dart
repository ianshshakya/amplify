import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final tracks = playlistProvider.likedSongsTracks;

    return Scaffold(
      appBar: AppBar(title: const Text('Liked Songs')),
      body: Column(
        children: [
          if (tracks.isNotEmpty)
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
                      context.read<PlayerProvider>().playTrack(tracks.first, context: tracks);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: tracks.isEmpty
                ? const Center(
                    child: Text(
                      'Songs you like will appear here.\nTap the heart on any track.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      return TrackTile(track: tracks[index], context_: tracks);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

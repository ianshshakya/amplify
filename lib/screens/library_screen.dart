import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'liked_songs_screen.dart';
import 'playlist_screen.dart';
import 'downloaded_songs_screen.dart';
import 'auth_gate.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<void> _createPlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight,
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<PlaylistProvider>().createPlaylist(name);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight,
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      context.read<PlaylistProvider>().clear();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final auth = context.watch<AuthProvider>();
    final playlists = playlistProvider.playlists;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text('Your Library', style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _createPlaylistDialog(context),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: auth.user?.email ?? 'Log out',
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: playlistProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.favorite, color: Colors.white),
                        ),
                        title: const Text('Liked Songs'),
                        subtitle: Text(
                          '${playlistProvider.likedSongsTracks.length} songs',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                        ),
                      ),
                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.download, color: Colors.white),
                        ),
                        title: const Text('My Downloads'),
                        subtitle: const Text(
                          'Play your music offline',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DownloadedSongsScreen()),
                        ),
                      ),
                      for (final playlist in playlists)
                        ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.queue_music, color: Colors.white),
                          ),
                          title: Text(playlist.name),
                          subtitle: Text(
                            '${playlist.tracks.length} songs',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaylistScreen(playlistId: playlist.id),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

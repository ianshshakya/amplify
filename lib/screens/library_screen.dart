import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import 'liked_songs_screen.dart';
import 'album_screen.dart';
import 'playlist_screen.dart';
import 'downloaded_songs_screen.dart';
import 'auth_gate.dart';
import 'artist_screen.dart';

import 'settings_screen.dart';
import 'import/bring_your_music_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _createPlaylistDialog(BuildContext context, WidgetRef ref) async {
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

    if (name != null && name.isNotEmpty) {
      await ref.read(playlistProvider.notifier).createPlaylist(name);
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
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

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      ref.read(playlistProvider.notifier).clear();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistState = ref.watch(playlistProvider);
    final libraryState = ref.watch(libraryProvider);
    final authState = ref.watch(authProvider);
    final playlists = playlistState.playlists;
    final savedAlbums = libraryState.albums;
    final savedArtists = libraryState.artists;

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
                  onPressed: () => _createPlaylistDialog(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, size: 20),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: authState.user?.email ?? 'Log out',
                  onPressed: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ),
          Expanded(
            child: playlistState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.deepPurpleAccent, Color(0xFF16A6A1)], // Premium teal/purple
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded, color: Colors.white),
                        ),
                        title: const Text('Liked Songs'),
                        subtitle: Text(
                          '${playlistState.likedSongs.length} songs',
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
                            gradient: LinearGradient(
                              colors: [Colors.cyan.shade400, Colors.blue.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: const Icon(Icons.download_rounded, color: Colors.white),
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
                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF282828),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF16A6A1)),
                        ),
                        title: const Text('Bring Your Music'),
                        subtitle: const Text(
                          'Import from Spotify or YouTube Music',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BringYourMusicScreen()),
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
                      if (savedAlbums.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text('Saved Albums', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        ),
                      for (final album in savedAlbums)
                        ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(4),
                              image: album.thumbnailUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(album.thumbnailUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: album.thumbnailUrl.isEmpty ? const Icon(Icons.album, color: Colors.white) : null,
                          ),
                          title: Text(album.title),
                          subtitle: Text(
                            album.artistName,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumScreen(albumId: album.id),
                            ),
                          ),
                        ),
                      if (savedArtists.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text('Following', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        ),
                      for (final artist in savedArtists)
                        ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: artist.thumbnailUrl.isNotEmpty ? NetworkImage(artist.thumbnailUrl) : null,
                            child: artist.thumbnailUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                            backgroundColor: AppColors.surfaceHighlight,
                          ),
                          title: Text(artist.name),
                          subtitle: const Text(
                            'Artist',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArtistScreen(artistId: artist.id),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track.dart';
import '../services/music_service.dart';
import '../services/offline_service.dart';
import '../providers/playlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';
import '../widgets/mini_player.dart';

class CuratedPlaylistScreen extends StatefulWidget {
  final CuratedPlaylist playlist;

  const CuratedPlaylistScreen({super.key, required this.playlist});

  @override
  State<CuratedPlaylistScreen> createState() => _CuratedPlaylistScreenState();
}

class _CuratedPlaylistScreenState extends State<CuratedPlaylistScreen> {
  late Future<CuratedPlaylistData?> _playlistDataFuture;

  @override
  void initState() {
    super.initState();
    _playlistDataFuture = MusicService().getCuratedPlaylist(widget.playlist.id);
  }

  void _downloadFullPlaylist(BuildContext context, List<Track> tracks) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting download of ${tracks.length} songs...')),
    );
    
    final offlineService = OfflineService();
    final musicService = MusicService();
    int successCount = 0;

    for (var track in tracks) {
      if (!mounted) break;
      try {
        if (!await offlineService.isSongDownloaded(track.videoId)) {
          final streamUrl = await musicService.getAudioStreamUrl(track.videoId);
          await offlineService.downloadSong(track, streamUrl);
        }
        successCount++;
      } catch (e) {
        debugPrint('Failed to download ${track.title}: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded $successCount/${tracks.length} songs successfully!')),
      );
    }
  }

  void _saveAsMyPlaylist(BuildContext context, List<Track> tracks) async {
    final playlistsProvider = context.read<PlaylistProvider>();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Creating playlist: ${widget.playlist.title}...')),
    );

    try {
      // 1. Create a new playlist
      await playlistsProvider.createPlaylist(widget.playlist.title);
      
      // 2. Find the ID of the newly created playlist
      final newPlaylist = playlistsProvider.playlists.last;
      
      // 3. Add all tracks to it
      for (var track in tracks) {
        await playlistsProvider.addTrackToPlaylist(newPlaylist.id, track);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist saved to your Library!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save playlist: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<CuratedPlaylistData?>(
        future: _playlistDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Failed to load playlist', style: TextStyle(color: Colors.white)));
          }

          final data = snapshot.data!;
          final tracks = data.songs;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                      // Gradient overlay for readability
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.background.withOpacity(0.8),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.playlist.title,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.playlist.description,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Buttons Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadFullPlaylist(context, tracks),
                          icon: const Icon(Icons.download),
                          label: const Text('Download All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _saveAsMyPlaylist(context, tracks),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Save as My Playlist'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tracks List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return TrackTile(
                      track: tracks[index],
                      context_: tracks,
                    );
                  },
                  childCount: tracks.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
            ],
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

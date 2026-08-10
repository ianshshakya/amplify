import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_theme.dart';
import '../providers/home_provider.dart';
import '../providers/player_provider.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../widgets/track_tile.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/mini_player.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  final String albumId;
  const AlbumScreen({super.key, required this.albumId});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  @override
  Widget build(BuildContext context) {
    final albumDetailAsync = ref.watch(albumDetailProvider(widget.albumId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: albumDetailAsync.when(
        data: (album) {
          if (album == null) {
            return const Center(child: Text('Album not found', style: TextStyle(color: Colors.white)));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: const Color(0xFF181818),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'album-art-${widget.albumId}',
                        child: CachedNetworkImage(
                          imageUrl: album.thumbnailUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xFF121212),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              album.title,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${album.artistName} • ${album.year ?? ""}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFFB3B3B3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(
                        'Total duration: ${album.totalDuration}',
                        style: const TextStyle(color: Color(0xFFB3B3B3)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (album.tracks.isNotEmpty) {
                            ref.read(playerProvider.notifier).toggleShuffle();
                            ref.read(playerProvider.notifier).playTrack(album.tracks.first, context: album.tracks);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                          backgroundColor: const Color(0xFF282828),
                        ),
                        child: const Icon(Icons.shuffle, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (album.tracks.isNotEmpty) {
                            ref.read(playerProvider.notifier).playTrack(album.tracks.first, context: album.tracks);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                          backgroundColor: const Color(0xFF1DB954),
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = album.tracks[index];
                    return TrackTile(
                      track: track,
                      context_: album.tracks,
                      trackNumber: index + 1,
                    );
                  },
                  childCount: album.tracks.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
        loading: () => ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) => SkeletonLoader.trackTile(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading album: $error', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(albumDetailProvider(widget.albumId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

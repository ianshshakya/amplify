import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/player_provider.dart';
import '../models/podcast.dart';
import '../models/track.dart';
import '../services/podcast_service.dart';
import '../widgets/mini_player.dart';

class PodcastScreen extends ConsumerStatefulWidget {
  final String podcastId;
  const PodcastScreen({super.key, required this.podcastId});

  @override
  ConsumerState<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends ConsumerState<PodcastScreen> {
  late final Future<Podcast?> _podcastFuture;

  @override
  void initState() {
    super.initState();
    _podcastFuture = PodcastService().getPodcast(widget.podcastId);
  }

  void _showSpeedControl(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
              onTap: () {
                // Assuming playerProvider has a setSpeed method, ignored for now
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FutureBuilder<Podcast?>(
        future: _podcastFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Podcast not found', style: TextStyle(color: Colors.white)));
          }

          final podcast = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: const Color(0xFF181818),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(podcast.title),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: podcast.thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xFF121212)],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 60,
                        left: 16,
                        child: Text(
                          podcast.author,
                          style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final episode = podcast.episodes[index];
                    return ListTile(
                      leading: CachedNetworkImage(
                        imageUrl: episode.thumbnailUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(episode.title, style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${episode.publishedDate ?? ""} • ${episode.duration.toString()}', style: const TextStyle(color: Color(0xFFB3B3B3))),
                      trailing: IconButton(
                        icon: const Icon(Icons.speed, color: Colors.white54),
                        onPressed: () => _showSpeedControl(context),
                      ),
                      onTap: () {
                        final track = Track(
                          videoId: episode.videoId,
                          title: episode.title,
                          artist: episode.podcastTitle,
                          thumbnailUrl: episode.thumbnailUrl,
                          duration: episode.duration,
                        );
                        ref.read(playerProvider.notifier).playTrack(track, context: [track]);
                      },
                    );
                  },
                  childCount: podcast.episodes.length,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';
import '../models/mood_category.dart';
import '../models/track.dart';
import '../services/music_service.dart';
import '../widgets/track_tile.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/mini_player.dart';

class MoodScreen extends ConsumerStatefulWidget {
  final MoodPlaylist mood;
  const MoodScreen({super.key, required this.mood});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = MusicService()
        .getMoodPlaylist(widget.mood.playlistId)
        .then((data) => data?.songs ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FutureBuilder<List<Track>>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SkeletonLoader.trackTile(),
                    childCount: 10,
                  ),
                ),
              ],
            );
          } else if (snapshot.hasError) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverFillRemaining(
                  child: Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No tracks found', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            );
          }

          final tracks = snapshot.data!;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(tracks: tracks),
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
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  SliverAppBar _buildSliverAppBar({List<Track>? tracks}) {
    final color1 = widget.mood.color1 ?? const Color(0xFF181818);
    final color2 = widget.mood.color2 ?? const Color(0xFF121212);

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: color1,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(widget.mood.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color1, color2],
            ),
          ),
        ),
      ),
      bottom: tracks != null && tracks.isNotEmpty
          ? PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(playerProvider.notifier).playTrack(tracks.first, context: tracks);
                    },
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                      backgroundColor: const Color(0xFF1DB954),
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

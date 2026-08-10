import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_provider.dart';
import '../models/track.dart';
import '../widgets/track_tile.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/mini_player.dart';

class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsAsync = ref.watch(chartsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts'),
        backgroundColor: const Color(0xFF181818),
      ),
      backgroundColor: const Color(0xFF121212),
      body: chartsAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('No charts data available', style: TextStyle(color: Colors.white)));
          }

          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              Color rankColor = Colors.white;
              if (index == 0) rankColor = Colors.amber;
              else if (index == 1) rankColor = Colors.grey;
              else if (index == 2) rankColor = Colors.brown;

              return Row(
                children: [
                  Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TrackTile(
                      track: track,
                      context_: tracks,
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => ListView.builder(
          itemCount: 15,
          itemBuilder: (context, index) => SkeletonLoader.trackTile(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading charts: $error', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.refresh(chartsProvider),
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

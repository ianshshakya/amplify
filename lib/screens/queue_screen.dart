import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';
import '../widgets/mini_player.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final queue = playerState.queue;
    final currentTrack = playerState.currentTrack;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        backgroundColor: const Color(0xFF181818),
      ),
      backgroundColor: const Color(0xFF121212),
      body: queue.isEmpty && currentTrack == null
          ? const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.white)))
          : CustomScrollView(
              slivers: [
                if (currentTrack != null) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Now Playing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      color: const Color(0xFF1DB954).withOpacity(0.2),
                      child: TrackTile(
                        track: currentTrack,
                        context_: queue,
                      ),
                    ),
                  ),
                ],
                if (queue.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Next Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  SliverFillRemaining(
                    child: ReorderableListView.builder(
                      itemCount: queue.length,
                      onReorder: (oldIndex, newIndex) {
                        ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        return ListTile(
                          key: ValueKey(track.videoId + index.toString()),
                          title: TrackTile(
                            track: track,
                            context_: queue,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white54),
                                onPressed: () {
                                  ref.read(playerProvider.notifier).removeFromQueue(index);
                                },
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle, color: Colors.white54),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ]
              ],
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/playlist_provider.dart';
import '../providers/home_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/section_header.dart';
import '../widgets/mood_tile.dart';
import '../widgets/track_tile.dart';
import 'liked_songs_screen.dart';
import 'playlist_screen.dart';
import 'curated_playlist_screen.dart';
import 'charts_screen.dart';
import 'mood_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    final playlists = ref.watch(playlistProvider);
    final homeFeed = ref.watch(homeFeedProvider);
    final charts = ref.watch(chartsProvider);
    final moods = ref.watch(moodCategoriesProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Greeting ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(greeting, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),

          // ─── Quick Access Grid ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _QuickAccessCard(
                    title: 'Liked Songs',
                    icon: Icons.favorite,
                    color: Colors.purple.shade700,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                    ),
                  ),
                  for (final p in playlists.playlists.take(5))
                    _QuickAccessCard(
                      title: p.name,
                      icon: Icons.queue_music,
                      color: AppColors.surfaceHighlight,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PlaylistScreen(playlistId: p.id)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Charts ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeader(
              title: '🔥 Trending',
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChartsScreen()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: charts.when(
              data: (tracks) => SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tracks.take(10).length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return _ChartCard(track: t, rank: i + 1, allTracks: tracks);
                  },
                ),
              ),
              loading: () => SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 5,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SkeletonLoader.card(size: 140),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ─── Moods & Genres ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: moods.when(
              data: (cats) {
                if (cats.isEmpty) return const SizedBox.shrink();
                final allMoods = cats.expand((c) => c.playlists).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Browse by Mood'),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: allMoods.length,
                        itemBuilder: (context, i) {
                          final mood = allMoods[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 140,
                              child: MoodTile(
                                mood: mood,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MoodScreen(mood: mood),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ─── Curated For You ─────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Curated For You'),
          ),
          SliverToBoxAdapter(
            child: homeFeed.when(
              data: (sections) => sections.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Could not load explore feed.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final playlist = sections[index];
                          return _PlaylistCard(playlist: playlist);
                        },
                      ),
                    ),
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.7,
                  children: List.generate(4, (_) => SkeletonLoader.card(size: 160)),
                ),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Failed to load. Check your connection.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── Nested widgets ───────────────────────────────────────────────────────────

class _ChartCard extends ConsumerWidget {
  final Track track;
  final int rank;
  final List<Track> allTracks;

  const _ChartCard({required this.track, required this.rank, required this.allTracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playTrack(track, context: allTracks),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: track.thumbnailUrl,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(width: 140, height: 140, color: AppColors.surfaceHighlight),
                    errorWidget: (_, __, ___) =>
                        Container(width: 140, height: 140, color: AppColors.surfaceHighlight),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank == 1
                            ? Colors.amber
                            : rank == 2
                                ? Colors.grey[300]
                                : rank == 3
                                    ? const Color(0xFFCD7F32)
                                    : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final CuratedPlaylist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CuratedPlaylistScreen(playlist: playlist)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: playlist.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.surfaceHighlight),
                errorWidget: (_, __, ___) => Container(color: AppColors.surfaceHighlight),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            playlist.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


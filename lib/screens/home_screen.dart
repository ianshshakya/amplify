import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../providers/home_provider.dart';
import '../providers/player_provider.dart';
import '../providers/recommendation_provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../models/mood_category.dart';
import '../widgets/premium_image.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/section_header.dart';
import 'liked_songs_screen.dart';
import 'playlist_screen.dart';
import 'curated_playlist_screen.dart';
import 'all_artists_screen.dart';
import 'artist_screen.dart';
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
    final dailyMix = ref.watch(dailyMixProvider);
    final oneSongAway = ref.watch(oneSongAwayProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceHighlight,
        onRefresh: () async {
          ref.refresh(homeFeedProvider);
          ref.refresh(chartsProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── Header ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  greeting,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),

            // ─── Categories / Moods Chips ─────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    _MoodChip(title: 'Workout', icon: Icons.fitness_center),
                    _MoodChip(title: 'Chill', icon: Icons.coffee),
                    _MoodChip(title: 'Party', icon: Icons.celebration),
                    _MoodChip(title: 'Hip-hop', icon: Icons.album),
                    _MoodChip(title: 'Relax', icon: Icons.spa),
                    _MoodChip(title: 'Romance', icon: Icons.favorite),
                    _MoodChip(title: 'Focus', icon: Icons.computer),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ─── Speed Dial / Quick Picks (4x2 Grid) ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.0,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _QuickPickCard(
                      title: 'Liked Songs',
                      imageUrl: 'https://i.ytimg.com/vi/kffacxfA7G4/hq720.jpg', // Placeholder for liked
                      isLikedSongs: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                      ),
                    ),
                    // Use up to 5 curated playlists for the quick picks
                    ...homeFeed.maybeWhen(
                      data: (sections) => sections.take(5).map((p) => _QuickPickCard(
                        title: p.title,
                        imageUrl: p.thumbnailUrl,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CuratedPlaylistScreen(playlist: p)),
                        ),
                      )).toList(),
                      orElse: () => [],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ─── Discovery Pick (One Song Away) ─────────────────────────────
            SliverToBoxAdapter(
              child: oneSongAway.when(
                data: (track) {
                  if (track == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Discovery Pick'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => ref.read(playerProvider.notifier).playTrack(track, context: [track]),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                PremiumImage(
                                  imageUrl: track.thumbnailUrl,
                                  width: 80,
                                  height: 80,
                                  borderRadius: 8,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Recommended for you',
                                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        track.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        track.artist,
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 40),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ─── Trending Songs (Horizontal Scroll) ───────────────────────
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Trending Now',
                onSeeAll: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChartsScreen()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: charts.when(
                data: (tracks) => SizedBox(
                  height: 240, // Height for vertical song cards
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tracks.length > 15 ? 15 : tracks.length,
                    itemBuilder: (context, i) {
                      final t = tracks[i];
                      return _VerticalSongCard(track: t, contextTracks: tracks);
                    },
                  ),
                ),
                loading: () => SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SkeletonLoader.card(size: 160, borderRadius: 8),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ─── Made For You (Daily Mix) ──────────────────────────────────
            SliverToBoxAdapter(
              child: dailyMix.when(
                data: (mix) {
                  if (mix == null || mix.songs.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Made For You'),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: mix.songs.length > 10 ? 10 : mix.songs.length,
                          itemBuilder: (context, i) {
                            return _VerticalSongCard(track: mix.songs[i], contextTracks: mix.songs);
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ─── Artists You Might Like (Circular Discs) ──────────────────
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Top Artists',
                onSeeAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AllArtistsScreen()),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    _ArtistDisc(name: 'Arijit Singh', imageUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_500x500.jpg'),
                    _ArtistDisc(name: 'Taylor Swift', imageUrl: 'https://c.saavncdn.com/artists/Taylor_Swift_003_20200226074119_500x500.jpg'),
                    _ArtistDisc(name: 'The Weeknd', imageUrl: 'https://c.saavncdn.com/artists/The_Weeknd_002_20241003071400_500x500.jpg'),
                    _ArtistDisc(name: 'Shreya Ghoshal', imageUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_500x500.jpg'),
                    _ArtistDisc(name: 'Justin Bieber', imageUrl: 'https://c.saavncdn.com/artists/Justin_Bieber_005_20201127112218_500x500.jpg'),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ─── Dynamic Categories (e.g. Trending, Top Charts) ───────────────
            SliverToBoxAdapter(
              child: homeFeed.when(
                data: (sections) {
                  if (sections.isEmpty) return const SizedBox.shrink();

                  // Group all playlists by their type
                  final Map<String, List<CuratedPlaylist>> grouped = {};
                  for (final p in sections) {
                    // Initialize list if not present
                    if (!grouped.containsKey(p.type)) {
                      grouped[p.type] = [];
                    }
                    grouped[p.type]!.add(p);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(title: entry.key),
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: entry.value.length,
                              itemBuilder: (context, index) {
                                return _PlaylistSquareCard(playlist: entry.value[index]);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Loading...'),
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: 4,
                        itemBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: SkeletonLoader.card(size: 160, borderRadius: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom player
          ],
        ),
      ),
    );
  }
}

// ─── Reusable YT-Music Style Components ─────────────────────────────────────

class _QuickPickCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final bool isLikedSongs;

  const _QuickPickCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.isLikedSongs = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
              child: isLikedSongs
                  ? Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF450af5), Color(0xFFc4efd9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 24),
                    )
                  : PremiumImage(
                      imageUrl: imageUrl,
                      width: 56,
                      height: 56,
                      borderRadius: 0,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _VerticalSongCard extends ConsumerWidget {
  final Track track;
  final List<Track> contextTracks;

  const _VerticalSongCard({required this.track, required this.contextTracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playTrack(track, context: contextTracks),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumImage(
              imageUrl: track.thumbnailUrl,
              width: 160,
              height: 160,
              borderRadius: 8,
            ),
            const SizedBox(height: 12),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistDisc extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _ArtistDisc({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArtistScreen(artistId: name)),
      ),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            ClipOval(
              child: PremiumImage(
                imageUrl: imageUrl,
                width: 130,
                height: 130,
                borderRadius: 65, // Circular
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistSquareCard extends StatelessWidget {
  final CuratedPlaylist playlist;

  const _PlaylistSquareCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CuratedPlaylistScreen(playlist: playlist)),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumImage(
              imageUrl: playlist.thumbnailUrl,
              width: 160,
              height: 160,
              borderRadius: 8,
            ),
            const SizedBox(height: 12),
            Text(
              playlist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              playlist.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String title;
  final IconData icon;

  const _MoodChip({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            // Push to MoodScreen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MoodScreen(
                  mood: MoodPlaylist(
                    playlistId: title.toLowerCase(),
                    title: title,
                    thumbnailUrl: '',
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

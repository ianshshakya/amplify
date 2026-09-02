import 'dart:ui';
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
      child: Stack(
        children: [
          // ─── Ambient Glowing Background ───
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            top: 300,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent.withOpacity(0.15),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // ─── Main Content ───
          RefreshIndicator(
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
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),

                // ─── Edge-to-Edge Discovery Hero Card ─────────────────────────
                SliverToBoxAdapter(
                  child: oneSongAway.when(
                    data: (track) {
                      if (track == null) return const SizedBox.shrink();
                      return _HeroDiscoveryCard(track: track);
                    },
                    loading: () => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SkeletonLoader.card(size: 220, borderRadius: 24),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ─── Categories / Moods Chips ─────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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

                // ─── Glassmorphic Quick Picks (4x2 Grid) ──────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3.0,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _QuickPickCard(
                          title: 'Liked Songs',
                          imageUrl: 'https://i.ytimg.com/vi/kffacxfA7G4/hq720.jpg', // Placeholder for liked
                          isLikedSongs: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                          ),
                        ),
                        ...homeFeed.maybeWhen(
                          data: (sections) => sections.take(5).map((p) => _QuickPickCard(
                            title: p.title,
                            imageUrl: p.thumbnailUrl,
                            isGlobalSongs: p.title.toLowerCase().contains('global'),
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

                const SliverToBoxAdapter(child: SizedBox(height: 36)),

                // ─── Trending Songs (Parallax Carousel) ───────────────────────
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
                    data: (tracks) {
                      final limitedTracks = tracks.take(15).toList();
                      return _ParallaxCarousel(tracks: limitedTracks);
                    },
                    loading: () => SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: 3,
                        itemBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: SkeletonLoader.card(size: 220, borderRadius: 16),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 36)),

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
                        if (!grouped.containsKey(p.type)) grouped[p.type] = [];
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
        ],
      ),
    );
  }
}

// ─── Premium Redesign Components ─────────────────────────────────────────────

class _HeroDiscoveryCard extends ConsumerWidget {
  final Track track;
  const _HeroDiscoveryCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playTrack(track, context: [track]),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PremiumImage(
                imageUrl: track.thumbnailUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'SONG OF THE DAY',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      track.title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Colors.white, height: 1.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ArtistScreen(artistId: track.artist)),
                              );
                            },
                            child: Text(
                              track.artist,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParallaxCarousel extends StatefulWidget {
  final List<Track> tracks;
  const _ParallaxCarousel({required this.tracks});

  @override
  State<_ParallaxCarousel> createState() => _ParallaxCarouselState();
}

class _ParallaxCarouselState extends State<_ParallaxCarousel> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.75);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.tracks.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.25)).clamp(0.0, 1.0);
              }
              return Center(
                child: SizedBox(
                  height: Curves.easeOut.transform(value) * 280,
                  width: Curves.easeOut.transform(value) * 250,
                  child: child,
                ),
              );
            },
            child: _CarouselTrackCard(track: widget.tracks[index], contextTracks: widget.tracks),
          );
        },
      ),
    );
  }
}

class _CarouselTrackCard extends ConsumerWidget {
  final Track track;
  final List<Track> contextTracks;
  const _CarouselTrackCard({required this.track, required this.contextTracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playTrack(track, context: contextTracks),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PremiumImage(
                imageUrl: track.thumbnailUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ArtistScreen(artistId: track.artist)),
                        );
                      },
                      child: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPickCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final bool isLikedSongs;
  final bool isGlobalSongs;

  const _QuickPickCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.isLikedSongs = false,
    this.isGlobalSongs = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: isLikedSongs || isGlobalSongs
                      ? Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isLikedSongs 
                                ? [Colors.pinkAccent.shade200, Colors.deepPurpleAccent]
                                : [Colors.blueAccent, Colors.cyanAccent.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            isLikedSongs ? Icons.favorite_rounded : Icons.public_rounded, 
                            color: Colors.white, 
                            size: 32,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        )
                      : PremiumImage(
                          imageUrl: imageUrl,
                          width: 60,
                          height: 60,
                          borderRadius: 0,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
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
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
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
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
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
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumImage(
              imageUrl: track.thumbnailUrl,
              width: 140,
              height: 140,
              borderRadius: 12,
            ),
            const SizedBox(height: 12),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ArtistScreen(artistId: track.artist)),
                );
              },
              child: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withOpacity(0.6),
                ),
              ),
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
        width: 110,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
                ],
              ),
              child: ClipOval(
                child: PremiumImage(
                  imageUrl: imageUrl,
                  width: 110,
                  height: 110,
                  borderRadius: 55, // Circular
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
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
    final isGlobalSongs = playlist.title.toLowerCase().contains('global');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CuratedPlaylistScreen(playlist: playlist)),
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: isGlobalSongs
                  ? Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent, Colors.cyanAccent.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.public_rounded,
                        color: Colors.white,
                        size: 64,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                    )
                  : PremiumImage(
                      imageUrl: playlist.thumbnailUrl,
                      width: 140,
                      height: 140,
                      borderRadius: 12,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              playlist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              playlist.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/playlist_provider.dart';
import '../theme/app_theme.dart';
import '../providers/player_provider.dart';
import '../services/user_data_service.dart';
import '../services/music_service.dart';
import '../models/track.dart';
import 'liked_songs_screen.dart';
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<HomeSection>> _homeFeedFuture;

  @override
  void initState() {
    super.initState();
    _homeFeedFuture = MusicService().getHomeFeed();
  }

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return SafeArea(
      child: FutureBuilder<List<HomeSection>>(
        future: _homeFeedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          
          final sections = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(greeting, style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    for (final playlist in playlists.playlists.take(5))
                      _QuickAccessCard(
                        title: playlist.name,
                        icon: Icons.queue_music,
                        color: AppColors.surfaceHighlight,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlaylistScreen(playlistId: playlist.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (sections.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Could not load explore feed.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              for (final section in sections)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(section.title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: section.songs.length,
                        itemBuilder: (context, index) {
                          final track = section.songs[index];
                          return _TrackCard(track: track, contextList: section.songs);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final Track track;
  final List<Track> contextList;

  const _TrackCard({required this.track, required this.contextList});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<PlayerProvider>().playTrack(track, context: contextList),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.surfaceHighlight),
                  errorWidget: (context, url, error) => Container(color: AppColors.surfaceHighlight),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
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
              color: color,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

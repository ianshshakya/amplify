import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late Future<List<Track>> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _getRecommendations();
  }

  Future<List<Track>> _getRecommendations() async {
    try {
      final history = await UserDataService().fetchWatchHistory();
      if (history.isNotEmpty) return history;
      // Fallback for new accounts
      return await MusicService().search('Top global hit songs');
    } catch (e) {
      // In case of error, just return something generic
      return await MusicService().search('lofi hip hop radio');
    }
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(greeting, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GridView.count(
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
          const SizedBox(height: 24),
          Text('Made for you', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: FutureBuilder<List<Track>>(
              future: _recommendationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text(
                    'Search for your favorite songs to start.',
                    style: TextStyle(color: AppColors.textSecondary),
                  );
                }
                
                final tracks = snapshot.data!;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return GestureDetector(
                      onTap: () => context.read<PlayerProvider>().playTrack(track, context: tracks),
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Image.network(
                                  track.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceHighlight),
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
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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

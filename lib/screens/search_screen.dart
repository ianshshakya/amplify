import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../providers/home_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import '../widgets/mood_tile.dart';
import '../widgets/skeleton_loader.dart';
import 'artist_screen.dart';
import 'album_screen.dart';
import 'mood_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final moodsAsync = ref.watch(moodCategoriesProvider);

    return SafeArea(
      child: Column(
        children: [
          // ─── Search Bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: (val) => ref.read(searchProvider.notifier).onQueryChanged(val),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'What do you want to listen to?',
                hintStyle: const TextStyle(color: Colors.black54),
                prefixIcon: const Icon(Icons.search, color: Colors.black87),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.black54),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchProvider.notifier).clearQuery();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ─── Filter Chips (only when search query is active) ──────────────
          if (_controller.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SearchFilter.values.map((filter) {
                    final isSelected = searchState.filter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          filter.name[0].toUpperCase() + filter.name.substring(1),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onSelected: (_) => ref.read(searchProvider.notifier).setFilter(filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ─── Main Body ────────────────────────────────────────────────────
          Expanded(
            child: _buildBody(searchState, moodsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SearchState state, AsyncValue<List<dynamic>> moodsAsync) {
    if (_controller.text.trim().isEmpty) {
      return _buildBrowseOrHistory(state, moodsAsync);
    }

    if (state.isLoading) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => SkeletonLoader.trackTile(),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text(state.error!, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    if (!state.hasResults) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Render results based on chosen filter
    return switch (state.filter) {
      SearchFilter.songs || SearchFilter.playlists => ListView.builder(
          itemCount: state.songResults.length,
          itemBuilder: (context, index) {
            return TrackTile(
              track: state.songResults[index],
              context_: state.songResults,
            );
          },
        ),
      SearchFilter.albums => GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: state.albumResults.length,
          itemBuilder: (context, index) {
            final album = state.albumResults[index];
            return AlbumCard(
              album: album,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AlbumScreen(albumId: album.id)),
              ),
            );
          },
        ),
      SearchFilter.artists => ListView.builder(
          itemCount: state.artistResults.length,
          itemBuilder: (context, index) {
            final artist = state.artistResults[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: artist.thumbnailUrl.isNotEmpty
                    ? NetworkImage(artist.thumbnailUrl)
                    : null,
                child: artist.thumbnailUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(artist.name, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ArtistScreen(artistId: artist.id)),
              ),
            );
          },
        ),
    };
  }

  Widget _buildBrowseOrHistory(SearchState state, AsyncValue<List<dynamic>> moodsAsync) {
    if (state.recentSearches.isNotEmpty) {
      return ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Recent Searches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...state.recentSearches.take(5).map((query) => ListTile(
                leading: const Icon(Icons.history, color: AppColors.textSecondary),
                title: Text(query, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  _controller.text = query;
                  ref.read(searchProvider.notifier).onQueryChanged(query);
                },
              )),
          const Divider(color: Color(0xFF282828)),
          _buildBrowseCategories(moodsAsync),
        ],
      );
    }

    return _buildBrowseCategories(moodsAsync);
  }

  Widget _buildBrowseCategories(AsyncValue<List<dynamic>> moodsAsync) {
    return moodsAsync.when(
      data: (cats) {
        if (cats.isEmpty) return const SizedBox.shrink();
        final allMoods = cats.expand((c) => c.playlists).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Browse all', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: allMoods.length,
              itemBuilder: (context, i) {
                final mood = allMoods[i];
                return MoodTile(
                  mood: mood,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MoodScreen(mood: mood)),
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: List.generate(8, (_) => const SkeletonLoader(width: double.infinity, height: 100)),
      ),
      error: (_, __) => const Center(
        child: Text('Failed to load genres', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

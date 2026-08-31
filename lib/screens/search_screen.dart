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
import '../providers/voice_provider.dart';
import '../models/voice_command.dart';

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
            child: Stack(
              children: [
                _buildBody(searchState, moodsAsync),
                
                // Floating Voice Control Pill
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: _FloatingVoiceBar(),
                ),
              ],
            ),
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
              context_: [state.songResults[index]],
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

/// A modern, floating voice control pill designed for the search screen.
class _FloatingVoiceBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FloatingVoiceBar> createState() => _FloatingVoiceBarState();
}

class _FloatingVoiceBarState extends ConsumerState<_FloatingVoiceBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);
    final isListening = voiceState.feedback == VoiceFeedback.listening;
    final isProcessing = voiceState.feedback == VoiceFeedback.processing;

    // Auto-reset after success/error
    if (voiceState.feedback == VoiceFeedback.success ||
        voiceState.feedback == VoiceFeedback.error) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) notifier.reset();
      });
    }

    // Hide if idle to keep it minimal, or just show a small mic button?
    // The user wants it optimal. Let's make it a prominent Floating Search Pill.
    return GestureDetector(
      onTap: () => notifier.toggleListening(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        decoration: BoxDecoration(
          color: isListening 
              ? const Color(0xFF1DB954) 
              : const Color(0xFF282828),
          borderRadius: BorderRadius.circular(30), // Pill shape
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isListening)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: const Icon(Icons.mic, color: Colors.white, size: 24),
                ),
              )
            else if (isProcessing)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white,
                ),
              )
            else if (voiceState.feedback == VoiceFeedback.success)
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 24)
            else if (voiceState.feedback == VoiceFeedback.error)
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 24)
            else
              const Icon(Icons.mic_none, color: Colors.white, size: 24),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isListening
                        ? 'Tap to stop listening'
                        : isProcessing
                            ? 'Processing…'
                            : voiceState.feedback == VoiceFeedback.success
                                ? voiceState.feedbackMessage
                                : voiceState.feedback == VoiceFeedback.error
                                    ? voiceState.feedbackMessage
                                    : 'Tap to voice search',
                    style: TextStyle(
                      color: voiceState.feedback == VoiceFeedback.error
                          ? Colors.redAccent
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (voiceState.recognizedText.isNotEmpty && isListening)
                    Text(
                      '"${voiceState.recognizedText}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

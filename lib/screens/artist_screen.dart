import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/home_provider.dart';
import '../providers/artist_songs_provider.dart';
import '../widgets/track_tile.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/section_header.dart';
import '../widgets/mini_player.dart';
import 'album_screen.dart';

class ArtistScreen extends ConsumerStatefulWidget {
  final String artistId;
  const ArtistScreen({super.key, required this.artistId});

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  bool _isFollowing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(artistSongsProvider(widget.artistId).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artistDetailAsync = ref.watch(artistDetailProvider(widget.artistId));
    final songsState = ref.watch(artistSongsProvider(widget.artistId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: artistDetailAsync.when(
        data: (artist) {
          if (artist == null) {
            return const Center(child: Text('Artist not found', style: TextStyle(color: Colors.white)));
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: const Color(0xFF181818),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    artist.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: artist.thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xFF121212),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 60,
                        left: 16,
                        child: Text(
                          '${artist.subscribers} Subscribers',
                          style: const TextStyle(
                            color: Color(0xFFB3B3B3),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? const Color(0xFF1DB954) : Colors.transparent,
                        side: _isFollowing ? null : const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFollowing = !_isFollowing;
                        });
                      },
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              
              if (artist.albums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: const SectionHeader(title: 'Albums', padding: EdgeInsets.all(16)),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: artist.albums.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: AlbumCard(
                            album: artist.albums[index],
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => AlbumScreen(albumId: artist.albums[index].id),
                              ));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              
              if (artist.singles.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: const SectionHeader(title: 'Singles', padding: EdgeInsets.all(16)),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: artist.singles.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: AlbumCard(
                            album: artist.singles[index],
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => AlbumScreen(albumId: artist.singles[index].id),
                              ));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              
              if (artist.relatedArtists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: const SectionHeader(title: 'Related Artists', padding: EdgeInsets.all(16)),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: artist.relatedArtists.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: ArtistCard(
                            artist: artist.relatedArtists[index],
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ArtistScreen(artistId: artist.relatedArtists[index].id),
                              ));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              
              SliverToBoxAdapter(
                child: const SectionHeader(title: 'All Songs', padding: EdgeInsets.all(16)),
              ),
              
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == songsState.songs.length) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: songsState.hasReachedMax 
                              ? const Text('End of Discography', style: TextStyle(color: Colors.white54))
                              : const CircularProgressIndicator(color: Color(0xFF1DB954)),
                        ),
                      );
                    }
                    return TrackTile(
                      track: songsState.songs[index],
                      context_: songsState.songs,
                      trackNumber: index + 1,
                    );
                  },
                  childCount: songsState.songs.length + 1,
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // padding for miniplayer
            ],
          );
        },
        loading: () => ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) => SkeletonLoader.trackTile(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading artist: $error', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(artistDetailProvider(widget.artistId)),
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

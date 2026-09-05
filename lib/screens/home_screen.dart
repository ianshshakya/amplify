import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_feed.dart';
import '../models/track.dart';
import '../providers/home_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_image.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/section_header.dart';
import 'curated_playlist_screen.dart';
import 'liked_songs_screen.dart';

/// A server-ranked browse surface. It keeps presentation local and delegates
/// taste, session and diversity decisions to HomeFeedEngine.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(dynamicHomeFeedProvider);
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.read(homeRefreshProvider.notifier).state = true;
          await ref.read(dynamicHomeFeedProvider.future);
        },
        child: feed.when(
          loading: () => const _HomeSkeleton(),
          error: (_, __) => _FeedView(greeting: _localGreeting(), sections: const []),
          data: (value) => _FeedView(greeting: value?.greeting ?? _localGreeting(), sections: value?.sections ?? const []),
        ),
      ),
    );
  }

  String _localGreeting() {
    final hour = DateTime.now().hour;
    return hour < 5 ? 'Good night' : hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  }
}

class _FeedView extends ConsumerWidget {
  final String greeting;
  final List<HomeFeedSection> sections;
  const _FeedView({required this.greeting, required this.sections});

  @override
  Widget build(BuildContext context, WidgetRef ref) => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 22), child: Text(greeting, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)))),
          if (sections.isEmpty) const SliverToBoxAdapter(child: _EmptyHome()),
          ...sections.map((section) => SliverToBoxAdapter(child: _FeedSection(section: section))),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      );
}

class _FeedSection extends ConsumerWidget {
  final HomeFeedSection section;
  const _FeedSection({required this.section});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quick = section.type == 'QUICK_PICKS';
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: section.title),
        if (section.subtitle.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: Text(section.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60))),
        SizedBox(height: quick ? 116 : 224, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: section.items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, index) => _FeedCard(item: section.items[index], compact: quick, analyticsContext: 'home_${section.type.toLowerCase()}'),
        )),
      ]),
    );
  }
}

class _FeedCard extends ConsumerWidget {
  final HomeFeedItem item;
  final bool compact;
  final String analyticsContext;
  const _FeedCard({required this.item, required this.compact, required this.analyticsContext});
  void _open(BuildContext context, WidgetRef ref) {
    if (item.type == 'SONG' && item.track != null) { ref.read(playerProvider.notifier).playTrack(item.track!, context: [item.track!], analyticsContext: analyticsContext); return; }
    if (item.id == 'liked-songs') { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LikedSongsScreen())); return; }
    final id = item.metadata['playlistId'] as String? ?? item.id;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CuratedPlaylistScreen(playlist: CuratedPlaylist(id: id, title: item.title, type: item.type, thumbnailUrl: item.imageUrl, description: item.subtitle))));
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    borderRadius: BorderRadius.circular(14), onTap: () => _open(context, ref), child: SizedBox(width: compact ? 178 : 150, child: compact ? _CompactCard(item: item) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(14), child: PremiumImage(imageUrl: item.imageUrl, width: 150, height: 150, borderRadius: 0)), const SizedBox(height: 9),
      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)), Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
    ])),
  );
}

class _CompactCard extends StatelessWidget {
  final HomeFeedItem item;
  const _CompactCard({required this.item});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(12)), child: Row(children: [
    ClipRRect(borderRadius: BorderRadius.circular(8), child: PremiumImage(imageUrl: item.imageUrl, width: 58, height: 58, borderRadius: 0)), const SizedBox(width: 9), Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
  ]));
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 30, 20, 120), children: [
    SkeletonLoader.card(size: 42, borderRadius: 8), const SizedBox(height: 30), for (var i = 0; i < 3; i++) ...[SkeletonLoader.card(size: 22, borderRadius: 6), const SizedBox(height: 14), SkeletonLoader.card(size: 150, borderRadius: 14), const SizedBox(height: 28)],
  ]);
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(24), child: Text('Your picks will appear here when you’re back online.', style: TextStyle(color: Colors.white60)));
}

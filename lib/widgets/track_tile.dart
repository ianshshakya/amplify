import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import 'download_indicator.dart';

/// A single track row used throughout the app.
/// Shows thumbnail, title, artist, and a three-dot context menu.
class TrackTile extends ConsumerWidget {
  final Track track;

  /// The full list of tracks in the current context (used to populate the queue).
  final List<Track> context_;

  /// Optional track number shown on the left instead of the thumbnail.
  final int? trackNumber;

  const TrackTile({
    super.key,
    required this.track,
    required this.context_,
    this.trackNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final isCurrentTrack = playerState.currentTrack?.videoId == track.videoId;
    final isPlaying = isCurrentTrack && playerState.isPlaying;
    final isLiked = ref.watch(playlistProvider).isLiked(track);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: () => ref.read(playerProvider.notifier).playTrack(track, context: context_),
      leading: _buildLeading(context, isCurrentTrack, isPlaying),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isCurrentTrack ? AppColors.primary : null,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: _ContextMenu(
        track: track,
        context_: context_,
        isLiked: isLiked,
      ),
    );
  }

  Widget _buildLeading(BuildContext context, bool isCurrent, bool isPlaying) {
    if (trackNumber != null) {
      return SizedBox(
        width: 32,
        child: Center(
          child: isCurrent
              ? Icon(
                  isPlaying ? Icons.volume_up : Icons.pause,
                  size: 18,
                  color: AppColors.primary,
                )
              : Text(
                  '$trackNumber',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: track.thumbnailUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 48,
              height: 48,
              color: AppColors.surfaceHighlight,
            ),
            errorWidget: (_, __, ___) => Container(
              width: 48,
              height: 48,
              color: AppColors.surfaceHighlight,
              child: const Icon(Icons.music_note, color: AppColors.textSecondary),
            ),
          ),
          if (isCurrent)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Icon(
                  isPlaying ? Icons.volume_up : Icons.pause,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three-dot context menu for a track.
class _ContextMenu extends ConsumerWidget {
  final Track track;
  final List<Track> context_;
  final bool isLiked;

  const _ContextMenu({
    required this.track,
    required this.context_,
    required this.isLiked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DownloadIndicator(track: track),
        PopupMenuButton<_TrackAction>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
          color: AppColors.surfaceHighlight,
          onSelected: (action) => _handleAction(context, ref, action),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _TrackAction.like,
              child: ListTile(
                leading: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? AppColors.heart : null,
                ),
                title: Text(isLiked ? 'Remove from Liked' : 'Like'),
              ),
            ),
            const PopupMenuItem(
              value: _TrackAction.addToQueue,
              child: ListTile(
                leading: Icon(Icons.queue_music),
                title: Text('Add to queue'),
              ),
            ),
            const PopupMenuItem(
              value: _TrackAction.addToPlaylist,
              child: ListTile(
                leading: Icon(Icons.playlist_add),
                title: Text('Add to playlist'),
              ),
            ),
            const PopupMenuItem(
              value: _TrackAction.download,
              child: ListTile(
                leading: Icon(Icons.download_outlined),
                title: Text('Download'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, _TrackAction action) {
    switch (action) {
      case _TrackAction.like:
        ref.read(playlistProvider.notifier).toggleLiked(track);
      case _TrackAction.addToQueue:
        ref.read(playerProvider.notifier).addToQueue(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${track.title}" to queue')),
        );
      case _TrackAction.addToPlaylist:
        _showAddToPlaylistDialog(context, ref);
      case _TrackAction.download:
        ref.read(downloadProvider.notifier).download(track);
    }
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref) {
    final playlists = ref.read(playlistProvider).playlists;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight,
        title: const Text('Add to Playlist'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.length,
            itemBuilder: (_, i) {
              final p = playlists[i];
              return ListTile(
                title: Text(p.name),
                onTap: () {
                  ref.read(playlistProvider.notifier).addTrackToPlaylist(p.id, track);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to ${p.name}')),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

enum _TrackAction { like, addToQueue, addToPlaylist, download }

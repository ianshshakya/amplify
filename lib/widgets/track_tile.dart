import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../theme/app_theme.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track> context_; // full list, used for next/previous
  final VoidCallback? onAddToPlaylist;

  const TrackTile({
    super.key,
    required this.track,
    required this.context_,
    this.onAddToPlaylist,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlists = context.watch<PlaylistProvider>();
    final isCurrentTrack = player.currentTrack?.videoId == track.videoId;
    final isLiked = playlists.isLiked(track);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Hero(
        tag: 'album_art_${track.videoId}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: track.thumbnailUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 48,
              height: 48,
              color: AppColors.surfaceHighlight,
            ),
            errorWidget: (context, url, error) => Container(
              width: 48,
              height: 48,
              color: AppColors.surfaceHighlight,
              child: const Icon(Icons.music_note, size: 20),
            ),
          ),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrentTrack ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(track.duration),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () => playlists.toggleLiked(track),
          ),
          if (onAddToPlaylist != null)
            IconButton(
              icon: const Icon(Icons.playlist_add, color: AppColors.textSecondary, size: 22),
              onPressed: onAddToPlaylist,
            ),
        ],
      ),
      onTap: () => player.playTrack(track, context: context_),
    );
  }
}

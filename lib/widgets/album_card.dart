import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/album.dart';
import '../theme/app_theme.dart';

/// Square album card with title and artist below, used in artist pages and search.
class AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final double size;

  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'album-art-${album.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: album.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: album.thumbnailUrl,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: size,
                          height: size,
                          color: AppColors.surfaceHighlight,
                        ),
                        errorWidget: (_, __, ___) => _placeholder(size),
                      )
                    : _placeholder(size),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${album.year != null ? "${album.year} • " : ""}${album.artistName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(double size) => Container(
        width: size,
        height: size,
        color: AppColors.surfaceHighlight,
        child: const Icon(Icons.album, color: AppColors.textSecondary, size: 48),
      );
}

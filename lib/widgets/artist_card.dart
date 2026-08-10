import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/artist.dart';
import '../theme/app_theme.dart';

/// Circular artist card with name below. Tapping navigates to ArtistScreen.
class ArtistCard extends ConsumerWidget {
  final ArtistSummary artist;
  final VoidCallback onTap;

  const ArtistCard({super.key, required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            Hero(
              tag: 'artist-${artist.id}',
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.surfaceHighlight,
                backgroundImage: artist.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImageProvider(artist.thumbnailUrl)
                    : null,
                child: artist.thumbnailUrl.isEmpty
                    ? const Icon(Icons.person, size: 40, color: AppColors.textSecondary)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Text(
              'Artist',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import 'skeleton_loader.dart';

/// A universal, premium image wrapper that gracefully handles:
/// - Lazy loading
/// - Fade-in transitions (blur-up equivalent)
/// - Skeleton loaders while fetching
/// - Elegant error fallbacks (no broken image icons)
class PremiumImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const PremiumImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if it's a valid URL, otherwise show fallback instantly
    final isValidUrl = imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: isValidUrl
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: fit,
                fadeInDuration: AppDurations.medium,
                placeholder: (context, url) => SkeletonLoader(width: width, height: height, borderRadius: borderRadius),
                errorWidget: (context, url, error) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceHighlight,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: width * 0.4,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }
}

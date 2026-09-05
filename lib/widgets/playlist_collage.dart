import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class PlaylistCollage extends StatelessWidget {
  final List<String> imageUrls;
  final double width;
  final double height;
  final double borderRadius;

  const PlaylistCollage({
    super.key,
    required this.imageUrls,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildCollage(),
    );
  }

  Widget _buildCollage() {
    final urls = imageUrls.where((u) => u.isNotEmpty).take(4).toList();

    if (urls.isEmpty) {
      return Icon(Icons.queue_music, color: Colors.white, size: width * 0.5);
    }

    if (urls.length == 1) {
      return _buildImage(urls[0]);
    }

    if (urls.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildImage(urls[0])),
          Expanded(child: _buildImage(urls[1])),
        ],
      );
    }

    if (urls.length == 3) {
      return Row(
        children: [
          Expanded(child: _buildImage(urls[0])),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildImage(urls[1])),
                Expanded(child: _buildImage(urls[2])),
              ],
            ),
          ),
        ],
      );
    }

    // 4 images
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImage(urls[0])),
              Expanded(child: _buildImage(urls[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImage(urls[2])),
              Expanded(child: _buildImage(urls[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surfaceHighlight,
        child: Icon(Icons.music_note, color: Colors.white54, size: width * 0.3),
      ),
    );
  }
}

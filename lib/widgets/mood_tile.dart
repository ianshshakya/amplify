import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mood_category.dart';
import '../theme/app_theme.dart';

/// Colorful gradient tile used in the mood/genre browsing grid.
class MoodTile extends StatelessWidget {
  final MoodPlaylist mood;
  final VoidCallback onTap;

  const MoodTile({super.key, required this.mood, required this.onTap});

  static const _fallbackPairs = [
    [Color(0xFFFF6D00), Color(0xFFFFAB40)],
    [Color(0xFFB71C1C), Color(0xFFEF5350)],
    [Color(0xFF1565C0), Color(0xFF42A5F5)],
    [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    [Color(0xFF00838F), Color(0xFF26C6DA)],
    [Color(0xFF880E4F), Color(0xFFE91E63)],
    [Color(0xFFE65100), Color(0xFFFF8A65)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = mood.title.length % _fallbackPairs.length;
    final color1 = mood.color1 ?? _fallbackPairs[idx][0];
    final color2 = mood.color2 ?? _fallbackPairs[idx][1];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Background thumbnail if available (decorative, slightly transparent)
              if (mood.thumbnailUrl.isNotEmpty)
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Opacity(
                    opacity: 0.25,
                    child: CachedNetworkImage(
                      imageUrl: mood.thumbnailUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  mood.title,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

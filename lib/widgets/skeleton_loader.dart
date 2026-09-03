import 'package:flutter/material.dart';

/// Animated shimmer loading placeholder. Use anywhere you need a loading skeleton.
///
/// Example:
/// ```dart
/// SkeletonLoader(width: double.infinity, height: 16, borderRadius: 8)
/// ```
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  /// Skeleton tile with a square thumb + two lines, mimicking a track row.
  static Widget trackTile() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SkeletonLoader(width: 48, height: 48, borderRadius: 4),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: double.infinity, height: 14, borderRadius: 6),
                  SizedBox(height: 6),
                  SkeletonLoader(width: 120, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      );

  /// Skeleton card for grid views.
  static Widget card({double size = 160, double borderRadius = 8}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: size, height: size, borderRadius: borderRadius),
          const SizedBox(height: 8),
          SkeletonLoader(width: size * 0.75, height: 13, borderRadius: 6),
          const SizedBox(height: 4),
          SkeletonLoader(width: size * 0.5, height: 11, borderRadius: 6),
        ],
      );

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _ctrl.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // slide from -1.0 to +1.0 relative to the bounds
    final dx = bounds.width * (slidePercent * 2 - 1);
    return Matrix4.translationValues(dx, 0.0, 0.0);
  }
}

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
  static Widget card({double size = 160}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: size, height: size, borderRadius: 8),
          const SizedBox(height: 8),
          SkeletonLoader(width: size * 0.75, height: 13, borderRadius: 6),
          const SizedBox(height: 4),
          SkeletonLoader(width: size * 0.5, height: 11, borderRadius: 6),
        ],
      );

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor.withOpacity(_anim.value * 0.15),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

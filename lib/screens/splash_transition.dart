import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CinematicSplashOverlay extends StatefulWidget {
  final bool isReady;
  final Widget child;

  const CinematicSplashOverlay({
    super.key,
    required this.isReady,
    required this.child,
  });

  @override
  State<CinematicSplashOverlay> createState() => _CinematicSplashOverlayState();
}

class _CinematicSplashOverlayState extends State<CinematicSplashOverlay>
    with TickerProviderStateMixin {

  // Fade in the splash content
  late final AnimationController _fadeInCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  // Fade out the entire splash overlay
  late final AnimationController _fadeOutCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _fadeInCtrl,
    curve: Curves.easeOut,
  );

  late final Animation<double> _fadeOut = CurvedAnimation(
    parent: _fadeOutCtrl,
    curve: Curves.easeIn,
  );

  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();
    _fadeInCtrl.forward();

    _fadeOutCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _isRevealed = true);
      }
    });

    if (widget.isReady) _triggerExit();
  }

  @override
  void didUpdateWidget(covariant CinematicSplashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady) _triggerExit();
  }

  void _triggerExit() {
    // Small hold, then fade out
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_fadeOutCtrl.isAnimating) _fadeOutCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeInCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRevealed) return widget.child;

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: Listenable.merge([_fadeIn, _fadeOut]),
          builder: (context, _) {
            // Combine: fade in * (1 - fade out)
            final opacity = _fadeIn.value * (1.0 - _fadeOut.value);
            return IgnorePointer(
              ignoring: _fadeOutCtrl.isAnimating,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  color: const Color(0xFF000000),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 88,
                            height: 88,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // App name — explicit style to prevent DefaultTextStyle yellow underline
                        const Text(
                          'Amplify',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            decoration: TextDecoration.none, // Prevent yellow debug underline
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your music, your way',
                          style: TextStyle(
                            color: Color(0xFF16A6A1), // App primary teal
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.none,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

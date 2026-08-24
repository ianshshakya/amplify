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

class _CinematicSplashOverlayState extends State<CinematicSplashOverlay> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _revealController;
  late final Animation<double> _pulseGlow;
  late final Animation<double> _pulseScale;
  late final Animation<double> _revealScale;
  late final Animation<double> _revealOpacity;

  bool _isRevealed = false;
  bool _startReveal = false;

  @override
  void initState() {
    super.initState();

    // 1. Pulsing Phase (While waiting for data)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.98, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    _pulseGlow = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 2. Reveal Phase (Triggered when ready)
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _revealScale = Tween<double>(begin: 1.0, end: 80.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeInOutExpo),
    );
    _revealOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isRevealed = true;
        });
      }
    });

    if (widget.isReady) {
      _triggerReveal();
    }
  }

  @override
  void didUpdateWidget(covariant CinematicSplashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady && !_startReveal) {
      _triggerReveal();
    }
  }

  void _triggerReveal() {
    setState(() => _startReveal = true);
    _pulseController.stop();
    // Give it a tiny delay to ensure the background frames are fully rendered
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _revealController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRevealed) {
      return widget.child;
    }

    return Stack(
      children: [
        // The background app (silently loading/rendering)
        widget.child,

        // The Splash Overlay
        AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _revealController]),
          builder: (context, child) {
            // Use reveal animations if starting reveal, otherwise use pulse animations
            final currentScale = _startReveal ? _revealScale.value : _pulseScale.value;
            final currentOpacity = _startReveal ? _revealOpacity.value : 1.0;
            final currentGlow = _startReveal ? 0.0 : _pulseGlow.value;

            return IgnorePointer(
              ignoring: _startReveal,
              child: Opacity(
                opacity: currentOpacity,
                child: Container(
                  color: AppColors.background, // Match OS splash screen exactly
                  child: Center(
                    child: Transform.scale(
                      scale: currentScale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: currentGlow,
                              spreadRadius: currentGlow * 0.5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 120,
                          height: 120,
                        ),
                      ),
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

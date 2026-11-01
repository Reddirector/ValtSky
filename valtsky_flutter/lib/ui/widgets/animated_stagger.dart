import 'package:flutter/material.dart';

class StaggeredFadeSlide extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;
  final Offset offset;

  const StaggeredFadeSlide({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 400),
    this.offset = const Offset(0, 0.05),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration + Duration(milliseconds: delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Calculate progress accounting for delay
        final totalMs = duration.inMilliseconds + delayMs;
        final currentMs = value * totalMs;
        final effectiveProgress = delayMs >= totalMs
            ? 1.0
            : ((currentMs - delayMs) / duration.inMilliseconds).clamp(0.0, 1.0);

        return Opacity(
          opacity: effectiveProgress,
          child: Transform.translate(
            offset: Offset(
              offset.dx * (1.0 - effectiveProgress) * 50,
              offset.dy * (1.0 - effectiveProgress) * 50,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class TactilePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const TactilePress({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
  });

  @override
  State<TactilePress> createState() => _TactilePressState();
}

class _TactilePressState extends State<TactilePress> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() => _isPressed = false);
          widget.onTap!();
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuad,
        child: widget.child,
      ),
    );
  }
}

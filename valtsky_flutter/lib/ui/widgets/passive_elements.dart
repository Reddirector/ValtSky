import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A subtle miniature 3-bar animated network audio/transfer visualizer.
class PassiveTransferWave extends StatefulWidget {
  final Color color;
  final bool isLive;

  const PassiveTransferWave({
    super.key,
    required this.color,
    this.isLive = true,
  });

  @override
  State<PassiveTransferWave> createState() => _PassiveTransferWaveState();
}

class _PassiveTransferWaveState extends State<PassiveTransferWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isLive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(PassiveTransferWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (index) => Container(
          width: 3,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1.5),
          ),
        )),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(4, (index) {
            final phase = (index * 0.25);
            final val = math.sin((_controller.value * 2 * math.pi) + phase);
            final height = 4.0 + (val.abs() * 10.0);

            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

/// A glowing ambient radar pulse dot for live indicators.
class AmbientRadarDot extends StatefulWidget {
  final Color color;
  final double size;

  const AmbientRadarDot({
    super.key,
    required this.color,
    this.size = 8.0,
  });

  @override
  State<AmbientRadarDot> createState() => _AmbientRadarDotState();
}

class _AmbientRadarDotState extends State<AmbientRadarDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final ringScale = 1.0 + (_controller.value * 1.2);
          final ringOpacity = (1.0 - _controller.value).clamp(0.0, 1.0) * 0.6;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer radiating ripple
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: ringOpacity),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Inner solid dot
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

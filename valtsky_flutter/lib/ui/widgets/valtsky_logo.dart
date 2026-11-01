import 'dart:math';
import 'package:flutter/material.dart';

/// Authentic ValtSky Logo Widget
/// Renders the signature Royal Blue Cloud with the White Telegram Paper Airplane
/// and the decorative 'V' base chevron from the official repository assets.
class ValtSkyLogo extends StatelessWidget {
  final double size;
  final bool isMonochrome;
  final Color? cloudColor;
  final Color? planeColor;
  final Color? chevronColor;

  const ValtSkyLogo({
    super.key,
    this.size = 32,
    this.isMonochrome = false,
    this.cloudColor,
    this.planeColor,
    this.chevronColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedCloud = cloudColor ??
        (isMonochrome
            ? (isDark ? Colors.white : Colors.black)
            : const Color(0xFF4F75FF));

    final resolvedPlane = planeColor ??
        (isMonochrome
            ? (isDark ? Colors.black : Colors.white)
            : Colors.white);

    final resolvedChevron = chevronColor ??
        (isMonochrome
            ? (isDark ? Colors.white : Colors.black)
            : const Color(0xFF4F75FF));

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ValtSkyLogoPainter(
          cloudColor: resolvedCloud,
          planeColor: resolvedPlane,
          chevronColor: resolvedChevron,
          useGradient: !isMonochrome && cloudColor == null,
        ),
      ),
    );
  }
}

class _ValtSkyLogoPainter extends CustomPainter {
  final Color cloudColor;
  final Color planeColor;
  final Color chevronColor;
  final bool useGradient;

  _ValtSkyLogoPainter({
    required this.cloudColor,
    required this.planeColor,
    required this.chevronColor,
    this.useGradient = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // The vector is designed in a 100x100 coordinate space
    // Bounding box of content: X ~ 10..95 (width 85), Y ~ 7..83 (height 76)
    // Center of shape: (52.5, 45.0)
    final s = min(size.width / 95.0, size.height / 90.0);
    final dx = (size.width - 105.0 * s) / 2;
    final dy = (size.height - 90.0 * s) / 2;

    canvas.translate(dx, dy);
    canvas.scale(s);

    // 1. Cloud Shape
    final cloudPath = Path()
      ..moveTo(25, 65)
      ..cubicTo(15, 65, 10, 57, 10, 48)
      ..cubicTo(10, 38, 18, 30, 28, 30)
      ..cubicTo(30, 17, 42, 7, 55, 7)
      ..cubicTo(66, 7, 76, 15, 79, 26)
      ..cubicTo(88, 28, 95, 35, 95, 45)
      ..cubicTo(95, 56, 87, 65, 76, 65)
      ..lineTo(25, 65)
      ..close();

    final cloudPaint = Paint()..style = PaintingStyle.fill;
    if (useGradient) {
      cloudPaint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF597FFF), Color(0xFF3652D9)],
      ).createShader(const Rect.fromLTWH(10, 7, 85, 58));
    } else {
      cloudPaint.color = cloudColor;
    }

    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(cloudPath, shadowPaint);
    canvas.restore();

    canvas.drawPath(cloudPath, cloudPaint);

    // 2. White Paper Plane symbol inside Cloud
    final planePath = Path()
      ..moveTo(42, 43)
      ..lineTo(62, 33)
      ..lineTo(54, 53)
      ..lineTo(50, 45)
      ..close();

    final planePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = planeColor;

    canvas.drawPath(planePath, planePaint);

    // 3. Decorative 'V' base chevron
    final chevronPath = Path()
      ..moveTo(35, 73)
      ..lineTo(50, 83)
      ..lineTo(65, 73);

    final chevronPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = chevronColor;

    canvas.drawPath(chevronPath, chevronPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ValtSkyLogoPainter oldDelegate) {
    return oldDelegate.cloudColor != cloudColor ||
        oldDelegate.planeColor != planeColor ||
        oldDelegate.chevronColor != chevronColor ||
        oldDelegate.useGradient != useGradient;
  }
}

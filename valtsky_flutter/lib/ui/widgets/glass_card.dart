import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 12,
    this.padding,
    this.margin,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);

    return ValueListenableBuilder<SyncEngineStatus>(
      valueListenable: SyncEngine.engineStatusNotifier,
      child: child,
      builder: (context, engineStatus, childWidget) {
        // High-Performance Optimization:
        // BackdropFilter is an expensive GPU shader operation (framebuffer copy + Gaussian blur pass).
        // During active sync, incoming transfer stats frequently trigger widget rebuilds.
        // Dynamically bypass BackdropFilter during active uploads and fall back to a high-performance
        // semi-transparent solid gradient background to eliminate raster thread bottlenecks and scroll lag.
        final isUploading = engineStatus == SyncEngineStatus.active;

        final cardContent = Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient ?? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [
                      cardBg.withAlpha(240),
                      const Color(0xFF07090F).withAlpha(245),
                    ] 
                  : [
                      Colors.white,
                      ValtSkyTheme.tertiaryLightSurface,
                    ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(
              color: borderColor,
              width: 1.2,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: childWidget,
          ),
        );

        return Container(
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 8),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: isUploading
                ? cardContent
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: cardContent,
                  ),
          ),
        );
      },
    );
  }
}

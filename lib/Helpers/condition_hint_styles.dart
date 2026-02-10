import 'package:flutter/material.dart';
import 'package:shoe_view/shoe_model.dart';
import 'dart:math' as math;

/// 🎨 Collection of premium visual hint styles for shoe conditions
class ConditionHintStyles {
  /// ⚡ ANIMATION CONTROLS
  static const double shimmerDurationMs = 5000.0; // Lower = Faster shimmer sweep
  static const double pulseDurationMs = 2500.0;     // Pulse speed for neon glow

  /// Defines the available hint style keys
  static const String sash = 'sash';
  static const String border = 'border';
  static const String glow = 'glow';
  static const String sweep = 'sweep';
  static const String pillar = 'pillar';

  /// Maps a style key to a human-readable name for the UI
  static Map<String, String> get styleNames => {
    sash: 'Corner Sash',
    border: 'Border Tint',
    glow: 'Neon Underglow',
    sweep: 'Light Sweep',
    pillar: 'L-Side Pillar',
  };

  /// Main entry point to wrap a widget with a hint style
  static Widget wrap({
    required Widget child,
    required Shoe shoe,
    required String style,
    required bool isEnabled,
    required Animation<double> animation,
  }) {
    if (!isEnabled) return child;

    switch (style) {
      case border:
        return _buildBorderHint(child, shoe, animation);
      case glow:
        return _buildGlowHint(child, shoe, animation);
      case sweep:
        return _buildSweepHint(child, shoe, animation);
      case pillar:
        return _buildPillarHint(child, shoe, animation);
      case sash:
      default:
        return _buildSashHint(child, shoe, animation);
    }
  }

  static Color getConditionColor(double condition) {
    if (condition >= 9.5) return Colors.amber[300]!;
    if (condition >= 9.0) return Colors.purple[200]!;
    if (condition >= 8.5) return Colors.red[300]!;
    if (condition >= 8.0) return Colors.brown[300]!;
    return Colors.lightBlue[200]!;
  }

  // --- Style Implementations ---

  static Widget _buildSashHint(Widget child, Shoe shoe, Animation<double> animation) {
    return CustomPaint(
      foregroundPainter: _SashPainter(
        shoe: shoe,
        animation: animation,
      ),
      child: child,
    );
  }

  static Widget _buildBorderHint(Widget child, Shoe shoe, Animation<double> animation) {
    final condition = shoe.condition;
    if (condition >= 10.0) {
      return CustomPaint(
        foregroundPainter: _RainbowBorderPainter(
          animation: animation,
          strokeWidth: 5.0,
          borderRadius: 12.0,
        ),
        child: child,
      );
    }

    final color = getConditionColor(condition);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(condition >= 9.5 ? 0.8 : 0.5),
          width: condition >= 9.5 ? 3.0 : 3.0,
        ),
      ),
      child: child,
    );
  }

  static Widget _buildGlowHint(Widget child, Shoe shoe, Animation<double> animation) {
    final condition = shoe.condition;
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, childWidget) {
        final color = (condition >= 10.0) 
            ? HSLColor.fromAHSL(1.0, (animation.value * 360), 0.8, 0.6).toColor()
            : getConditionColor(condition);

        final List<BoxShadow> shadows = [
          BoxShadow(
            color: color.withOpacity(condition >= 9.5 ? 0.5 : 0.3),
            blurRadius: 10 + (math.sin(animation.value * math.pi * 2) * 4),
            offset: const Offset(0, 5), // 🎯 Like a drop shadow elevation
            spreadRadius: 1,
          )
        ];

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: shadows,
          ),
          child: childWidget,
        );
      },
      child: child,
    );
  }

  static Widget _buildSweepHint(Widget child, Shoe shoe, Animation<double> animation) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _SweepPainter(
                shoe: shoe,
                animation: animation,
              ),
            ),
          ),
        ),
        // Force rainbow border if 10.0
        if (shoe.condition >= 10.0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                foregroundPainter: _RainbowBorderPainter(
                  animation: animation,
                  strokeWidth: 3.5,
                  borderRadius: 12.0,
                ),
              ),
            ),
          ),
      ],
    );
  }


  static Widget _buildPillarHint(Widget child, Shoe shoe, Animation<double> animation) {
    final condition = shoe.condition;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 12,
          bottom: 12,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              Color color;
              if (condition >= 10.0) {
                color = HSLColor.fromAHSL(1.0, (animation.value * 360), 0.8, 0.5).toColor();
              } else {
                color = getConditionColor(condition);
              }
              return Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              );
            },
          ),
        ),
        if (shoe.condition >= 10.0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                foregroundPainter: _RainbowBorderPainter(
                  animation: animation,
                  strokeWidth: 1.5,
                  borderRadius: 12.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 🌈 Painter for the rotating rainbow border
class _RainbowBorderPainter extends CustomPainter {
  final Animation<double> animation;
  final double strokeWidth;
  final double borderRadius;

  _RainbowBorderPainter({
    required this.animation,
    required this.strokeWidth,
    required this.borderRadius,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(math.max(0, borderRadius - strokeWidth / 2)),
    );

    final shader = SweepGradient(
      colors: const [
        Colors.red, Colors.orange, Colors.yellow, Colors.green,
        Colors.blue, Colors.indigo, Colors.purple, Colors.red,
      ],
      stops: const [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.84, 1.0],
      transform: GradientRotation(animation.value * 2 * math.pi),
    ).createShader(rect);

    final glowPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect, glowPaint);

    final mainPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, mainPaint);
  }

  @override
  bool shouldRepaint(covariant _RainbowBorderPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth || oldDelegate.borderRadius != borderRadius;
}

/// 🏷️ Custom Painter for the Sash style
class _SashPainter extends CustomPainter {
  final Shoe shoe;
  final Animation<double> animation;

  _SashPainter({required this.shoe, required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final condition = shoe.condition;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(28, 0)
      ..lineTo(0, 28)
      ..close();

    final paint = Paint()..style = PaintingStyle.fill;

    if (condition >= 10.0) {
      final shader = SweepGradient(
        colors: const [Color(0xFF00E5FF), Color(0xFFD500F9), Color(0xFFFFD600), Color(0xFF00E5FF)],
        stops: const [0.0, 0.4, 0.75, 1.0],
        transform: GradientRotation(animation.value * 2 * math.pi),
      ).createShader(const Rect.fromLTWH(0, 0, 40, 40));

      canvas.drawPath(path, Paint()
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      paint.shader = shader;
    } else {
      final color = ConditionHintStyles.getConditionColor(condition);
      if (condition >= 9.5) {
        canvas.drawPath(path, Paint()
          ..color = color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
      paint.color = color.withOpacity(0.85);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SashPainter oldDelegate) => false;
}

/// ☄️ Painter for the Light Sweep (sheen) effect
class _SweepPainter extends CustomPainter {
  final Shoe shoe;
  final Animation<double> animation;

  _SweepPainter({required this.shoe, required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final condition = shoe.condition;
    
    // 🎯 SYNC LOGIC: Use global time so all cards shimmer at exactly the same moment
    final int now = DateTime.now().millisecondsSinceEpoch;
    final double progress = (now % ConditionHintStyles.shimmerDurationMs.toInt()) / 
                             ConditionHintStyles.shimmerDurationMs;

    // 🎭 ANIME MOTION: Start slow, end fast (EaseIn)
    // We only want the shimmer to visible for the first 60% of the cycle, then pause
    const double visibleThreshold = 0.6;
    if (progress > visibleThreshold) return; 

    final double normalizedProgress = progress / visibleThreshold;
    final double easedProgress = Curves.easeInExpo.transform(normalizedProgress);
    
    // 📐 CORNER TO CORNER: Calculate diagonal vector
    final double diagonalScale = 2.5; 
    final Rect drawRect = Offset.zero & size;
    final double diagonalLength = math.sqrt(size.width * size.width + size.height * size.height);
    
    // Position moves along the diagonal path
    final double distance = (easedProgress * diagonalLength * diagonalScale) - (diagonalLength * 0.75);
    
    final accentColor = ConditionHintStyles.getConditionColor(condition);
    final List<Color> colors;
    
    if (condition >= 10.0) {
      // Rotating rainbow shimmer for Legendary
      final double hue = (now / 10) % 360;
      final legColor = HSLColor.fromAHSL(1.0, hue, 0.8, 0.6).toColor();
      colors = [
        legColor.withOpacity(0.0),
        legColor.withOpacity(0.3),
        Colors.white.withOpacity(0.8), // Inner glare
        legColor.withOpacity(0.3),
        legColor.withOpacity(0.0),
      ];
    } else {
      colors = [
        accentColor.withOpacity(0.0),
        accentColor.withOpacity(0.2),
        Colors.white.withOpacity(0.7), // ⚡ Sharp light core
        accentColor.withOpacity(0.4), // 🌈 Color background trail
        accentColor.withOpacity(0.0),
      ];
    }

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0.0, 0.4, 0.5, 0.7, 1.0], // Uneven stops for a "trail" effect
      ).createShader(Rect.fromLTWH(distance, distance, size.width, size.height));

    // Fill the card area with the moving gradient
    canvas.drawRect(drawRect, paint);
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) => true;
}

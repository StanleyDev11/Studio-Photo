import 'dart:math';
import 'package:flutter/material.dart';
import 'package:Picon/utils/colors.dart';

class GeometricBackground extends StatelessWidget {
  const GeometricBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;

    return Stack(
      children: [
        // Base background
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),

        // Directional light gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withOpacity(isDark ? 0.12 : 0.18),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6],
            ),
          ),
        ),

        // Large architectural diagonal block
        Positioned(
          top: -size.height * 0.15,
          right: -size.width * 0.3,
          child: Transform.rotate(
            angle: -pi / 6,
            child: Container(
              width: size.width * 1.2,
              height: size.height * 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withOpacity(0.08),
                    primary.withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(80),
              ),
            ),
          ),
        ),

        // Hexagon core element
        Positioned(
          bottom: size.height * 0.15,
          left: -80,
          child: SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: _AdvancedPolygonPainter(
                sides: 6,
                strokeColor: primary.withOpacity(0.35),
                fillGradient: RadialGradient(
                  colors: [
                    primary.withOpacity(0.15),
                    primary.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Thin architectural lines
        Positioned.fill(
          child: CustomPaint(
            painter: _LinePainter(primary.withOpacity(0.08)),
          ),
        ),
      ],
    );
  }
}

class _AdvancedPolygonPainter extends CustomPainter {
  final int sides;
  final Color strokeColor;
  final Gradient fillGradient;

  _AdvancedPolygonPainter({
    required this.sides,
    required this.strokeColor,
    required this.fillGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double angle = (2 * pi) / sides;
    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < sides; i++) {
      final x = center.dx + radius * cos(i * angle - pi / 2);
      final y = center.dy + radius * sin(i * angle - pi / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();

    final rect = Rect.fromCircle(center: center, radius: radius);

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinePainter extends CustomPainter {
  final Color color;

  _LinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Diagonal grid lines
    for (double i = -size.height; i < size.width; i += 120) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

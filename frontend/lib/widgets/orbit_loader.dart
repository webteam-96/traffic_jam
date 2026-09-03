import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A small moon in continuous circular orbit around a fixed central planet —
/// doubles as the app's "something is loading" indicator wherever it's used
/// (splash screen today), so it never needs a separate spinner alongside it.
class OrbitLoader extends StatefulWidget {
  const OrbitLoader({super.key, this.size = 140, this.orbitSeconds = 3});

  final double size;
  final int orbitSeconds;

  @override
  State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.orbitSeconds),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planetSize = widget.size * 0.46;
    final moonSize = widget.size * 0.13;
    final orbitDiameter = widget.size * 0.86;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Faint orbit path so the motion reads clearly against the
          // cosmic backdrop, not just a moon floating with no reference.
          CustomPaint(
            size: Size(orbitDiameter, orbitDiameter),
            painter: _OrbitRingPainter(),
          ),

          // Ambient glow, matching the app's existing gold-glow treatment.
          Container(
            width: planetSize,
            height: planetSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // The planet — Earth (NASA "Blue Marble", public domain — see
          // assets/images/earth.png), fixed at the center, not part of the
          // rotating layer. A recognizable planet reads clearer than an
          // abstract gold sphere for "this is loading."
          ClipOval(
            child: Image.asset(
              'assets/images/earth.png',
              width: planetSize,
              height: planetSize,
              fit: BoxFit.cover,
            ),
          ),

          // The moon — orbits by rotating a layer that holds it at a fixed
          // offset from the shared center; the planet above is unaffected
          // since it lives outside this rotating subtree.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.rotate(
              angle: _controller.value * 2 * pi,
              child: child,
            ),
            child: SizedBox(
              width: orbitDiameter,
              height: orbitDiameter,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: moonSize,
                  height: moonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textPrimary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) => false;
}

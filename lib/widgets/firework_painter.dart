import 'dart:math' as math;
import 'package:flutter/material.dart';

class FireworkParticle {
  FireworkParticle({
    required this.center,
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.delay,
  });

  final Offset center;
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double delay;
}

class FireworkPainter extends CustomPainter {
  FireworkPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<FireworkParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final localProgress =
          ((progress - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final eased = Curves.easeOutCubic.transform(localProgress);
      final fade = (1 - localProgress).clamp(0.0, 1.0);
      final center = Offset(
        particle.center.dx * size.width,
        particle.center.dy * size.height,
      );
      final offset = Offset(
        math.cos(particle.angle) * particle.distance * eased,
        math.sin(particle.angle) * particle.distance * eased +
            52 * localProgress * localProgress,
      );

      paint.color = particle.color.withValues(alpha: fade);
      canvas.drawCircle(center + offset, particle.size * fade + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FireworkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}

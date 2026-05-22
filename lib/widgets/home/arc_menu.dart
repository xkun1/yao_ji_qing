import 'dart:math' as math;
import 'package:flutter/material.dart';

class ArcMenuOverlay extends StatelessWidget {
  final bool isOpen;
  final AnimationController animationController;
  final VoidCallback onCameraEntry;
  final VoidCallback onManualEntry;
  final VoidCallback onAIChatEntry;

  const ArcMenuOverlay({
    super.key,
    required this.isOpen,
    required this.animationController,
    required this.onCameraEntry,
    required this.onManualEntry,
    required this.onAIChatEntry,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOpen && animationController.value == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              _buildArcButton(
                index: 0,
                total: 3,
                angle: -4 * math.pi / 5,
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFF3B82F6),
                onPressed: onCameraEntry,
              ),
              _buildArcButton(
                index: 1,
                total: 3,
                angle: -math.pi / 2,
                icon: Icons.psychology_rounded,
                color: const Color(0xFF8B5CF6),
                onPressed: onAIChatEntry,
              ),
              _buildArcButton(
                index: 2,
                total: 3,
                angle: -math.pi / 5,
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF10B981),
                onPressed: onManualEntry,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArcButton({
    required int index,
    required int total,
    required double angle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    const double distance = 110.0;
    final double start = (index / total) * 0.3;
    final double end = (start + 0.7).clamp(0.0, 1.0);

    final Animation<double> buttonAnimation = CurvedAnimation(
      parent: animationController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
      reverseCurve: Interval(1.0 - end, 1.0 - start, curve: Curves.easeInBack),
    );

    return AnimatedBuilder(
      animation: buttonAnimation,
      builder: (context, child) {
        final double v = buttonAnimation.value;
        if (v <= 0 && !isOpen) return const SizedBox.shrink();

        final double x = distance * math.cos(angle) * v;
        final double y = distance * math.sin(angle) * v;

        return Transform.translate(
          offset: Offset(x, y),
          child: Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.5 + 0.5 * v,
              child: Transform.rotate(
                angle: (1 - v) * 0.4,
                child: GestureDetector(
                  onTap: onPressed,
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

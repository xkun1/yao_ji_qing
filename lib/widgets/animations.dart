import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 识药/AI 处理中的药品主题加载动画
/// 替代生硬的 CircularProgressIndicator
class MedicinePulseLoader extends StatefulWidget {
  final String? message;
  final double size;

  const MedicinePulseLoader({super.key, this.message, this.size = 100});

  @override
  State<MedicinePulseLoader> createState() => _MedicinePulseLoaderState();
}

class _MedicinePulseLoaderState extends State<MedicinePulseLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _PulsePainter(progress: _controller.value),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dots = '.' * ((_controller.value * 6).floor() % 4);
              return Text(
                '${widget.message}$dots',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;

  _PulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 * 0.7;

    // 外环旋转
    _drawRotatingRing(canvas, center, radius);

    // 脉动核心圆
    _drawPulsingCore(canvas, center, radius * 0.35);

    // 中心十字图标
    _drawCross(canvas, center, radius * 0.22);
  }

  void _drawRotatingRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const gradientColors = [
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
    ];

    final double rotation = progress * math.pi * 2 * 3;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (int i = 0; i < 3; i++) {
      final arcProgress = ((progress + i / 3) % 1.0);
      final double startAngle = arcProgress * math.pi * 2;
      const double sweepAngle = math.pi * 0.6;

      ringPaint.color =
          gradientColors[i].withValues(alpha: 0.8 - arcProgress * 0.5);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        false,
        ringPaint,
      );
    }
    canvas.restore();
  }

  void _drawPulsingCore(Canvas canvas, Offset center, double baseRadius) {
    final double pulse = math.sin(progress * math.pi * 2) * 0.15;
    final double r = baseRadius * (1 + pulse);

    // 辉光
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.4),
          const Color(0xFF3B82F6).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.8));

    canvas.drawCircle(center, r * 1.8, glowPaint);

    // 实心圆
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: r));

    canvas.drawCircle(center, r, corePaint);
  }

  void _drawCross(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final double hw = size * 0.3;
    final double hh = size;
    // 竖
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: hw, height: hh * 1.1),
        const Radius.circular(8),
      ),
      paint,
    );
    // 横
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: size * 0.65, height: hw),
        const Radius.circular(8),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => true;
}

/// 空状态时展示的浮动动画图标
class FloatingEmptyIcon extends StatefulWidget {
  final String message;
  final String subMessage;
  final bool isAllDone;

  const FloatingEmptyIcon({
    super.key,
    required this.message,
    required this.subMessage,
    this.isAllDone = false,
  });

  @override
  State<FloatingEmptyIcon> createState() => _FloatingEmptyIconState();
}

class _FloatingEmptyIconState extends State<FloatingEmptyIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
        widget.isAllDone ? const Color(0xFF10B981) : const Color(0xFFE5E7EB);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double t = _controller.value;
            final double floatY = math.sin(t * math.pi * 2) * 10;
            final double scale = 1.0 + math.sin(t * math.pi * 2) * 0.04;

            return Transform.translate(
              offset: Offset(0, floatY),
              child: Transform.scale(
                scale: scale,
                child: CustomPaint(
                  size: const Size(80, 80),
                  painter: _FloatingIconPainter(
                    progress: t,
                    isAllDone: widget.isAllDone,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          widget.message,
          style: TextStyle(
            color: widget.isAllDone ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
            fontSize: 16,
            fontWeight: widget.isAllDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subMessage,
          style: TextStyle(
            color: accentColor.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FloatingIconPainter extends CustomPainter {
  final double progress;
  final bool isAllDone;

  _FloatingIconPainter({required this.progress, required this.isAllDone});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 * 0.8;
    final Color baseColor = isAllDone ? const Color(0xFF10B981) : const Color(0xFFE5E7EB);

    // 柔和阴影
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = baseColor.withValues(alpha: 0.15);
    final double shadowScale = 0.9 + math.sin(progress * math.pi * 2) * 0.06;
    canvas.drawCircle(
      Offset(center.dx, center.dy + 4),
      radius * shadowScale,
      shadowPaint,
    );

    // 背景圆
    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, bgPaint);

    // 边框圆
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = baseColor.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius, borderPaint);

    // 图标 - 勾号或药瓶
    final iconPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..color = baseColor.withValues(alpha: 0.7);

    if (isAllDone) {
      _drawCheckmark(canvas, center, radius * 0.5, iconPaint);
    } else {
      _drawMedicineIcon(canvas, center, radius * 0.45, iconPaint);
    }
  }

  void _drawCheckmark(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - size * 0.5, center.dy);
    path.lineTo(center.dx - size * 0.1, center.dy + size * 0.45);
    path.lineTo(center.dx + size * 0.5, center.dy - size * 0.35);
    canvas.drawPath(path, paint);
  }

  void _drawMedicineIcon(Canvas canvas, Offset center, double size, Paint paint) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = paint.color.withValues(alpha: 0.15);

    // 瓶身
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + size * 0.1),
        width: size * 0.8,
        height: size * 1.2,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRect, fillPaint);
    canvas.drawRRect(bodyRect, paint);

    // 瓶盖
    final capRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - size * 0.55),
        width: size * 0.7,
        height: size * 0.25,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(capRect, paint);

    // 十字
    final crossPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = paint.color;
    final double cw = size * 0.12;
    final double ch = size * 0.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: cw, height: ch),
        const Radius.circular(2),
      ),
      crossPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: ch * 0.7, height: cw),
        const Radius.circular(2),
      ),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FloatingIconPainter oldDelegate) => true;
}

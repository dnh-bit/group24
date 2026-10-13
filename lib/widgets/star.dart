import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// ستارهٔ هشت‌پر (همون نشان صفحهٔ اصلی) که آروم می‌چرخه
class SpinningStar extends StatefulWidget {
  final double size;
  final Color color;
  final Color hole;
  final bool spin;
  const SpinningStar({
    super.key,
    this.size = 72,
    this.color = AppColors.saffron,
    this.hole = AppColors.paper,
    this.spin = true,
  });

  @override
  State<SpinningStar> createState() => _SpinningStarState();
}

class _SpinningStarState extends State<SpinningStar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void initState() {
    super.initState();
    if (widget.spin) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _StarPainter(widget.color, widget.hole),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  final Color hole;
  _StarPainter(this.color, this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = size.width / 100;
    final paint = Paint()..color = color;
    final rect = Rect.fromCenter(center: Offset.zero, width: 64 * unit, height: 64 * unit);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.drawRect(rect, paint);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(rect, paint);
    canvas.restore();
    canvas.drawCircle(c, 14 * unit, Paint()..color = hole);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color || old.hole != hole;
}

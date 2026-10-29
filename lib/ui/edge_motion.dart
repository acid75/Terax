import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/terax_theme.dart';

/// A passive effect driven exclusively by a real transfer's timeline.
class EdgeMotion extends StatelessWidget {
  const EdgeMotion({
    super.key,
    required this.top,
    required this.timeline,
    this.active = true,
    this.failed = false,
  });
  final bool top, active, failed;
  final Animation<double> timeline;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: timeline,
      builder: (context, _) => CustomPaint(
        painter: _EdgePainter(
          colors: TeraxColors.of(context),
          top: top,
          progress: timeline.value,
          visible: active && !failed,
          reduced: MediaQuery.disableAnimationsOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.colors,
    required this.top,
    required this.progress,
    required this.visible,
    required this.reduced,
  });
  final TeraxColors colors;
  final bool top, visible, reduced;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (!visible || size.isEmpty) return;
    final p = progress.clamp(0.0, 1.0);
    final edge = Offset(size.width / 2, top ? 0 : size.height);
    final strength = (1 - p) * .55;
    // Elliptical radial falloff reaches zero before the text below the edge.
    final depth = math.min(size.height, TeraxMotion.edgeZoneHeight / 2);
    canvas.save();
    canvas.translate(edge.dx, edge.dy);
    canvas.scale(size.width / (depth * 2), 1);
    canvas.drawCircle(
      Offset.zero,
      depth,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colors.mint.withValues(alpha: strength),
            colors.mint.withValues(alpha: strength * .4),
            TeraxColors.clear,
          ],
          stops: const [0, .38, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: depth)),
    );
    canvas.restore();
    // The reference specifies a 3 dp edge line (not a control size).
    canvas.drawRect(
      Rect.fromLTWH(0, top ? 0 : size.height - 3, size.width, 3),
      Paint()..color = colors.mint.withValues(alpha: 1 - p),
    );
    if (top || reduced || p >= 1) return;
    for (final delay in const [0.0, .22]) {
      final wave = ((p - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (wave <= 0) continue;
      canvas.drawOval(
        Rect.fromCenter(
          center: edge,
          width: size.width * wave * 1.4,
          height: size.height * wave * 1.05,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = TeraxSize.focusBorder
          ..color = colors.mint.withValues(alpha: (1 - wave) * .35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.colors != colors ||
      old.top != top ||
      old.progress != progress ||
      old.visible != visible ||
      old.reduced != reduced;
}

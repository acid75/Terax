import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/terax_theme.dart';

/// A live light wave inside Flutter. Never captures or freezes screen pixels.
class TransferWave extends StatelessWidget {
  const TransferWave({
    super.key,
    required this.timeline,
    required this.incoming,
  });
  final Animation<double> timeline;
  final bool incoming;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: timeline,
          builder: (context, _) => CustomPaint(
            painter: _TransferWavePainter(
              TeraxColors.of(context),
              timeline.value,
              incoming,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class _TransferWavePainter extends CustomPainter {
  const _TransferWavePainter(this.colors, this.progress, this.incoming);
  final TeraxColors colors;
  final double progress;
  final bool incoming;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || progress >= 1) return;
    final p = progress.clamp(0.0, 1.0);
    final travel = Curves.easeInOutCubic.transform(p);
    final origin = Offset(size.width / 2, incoming ? size.height : 0);
    final reach = math.sqrt(
      size.width * size.width / 4 + size.height * size.height,
    );
    final radius = reach * (incoming ? travel : 1 - travel);
    final band = math.min(TeraxMotion.edgeZoneHeight, size.shortestSide * .25);
    final outer = radius + band;
    final inner = math.max(0.0, radius - band) / outer;
    final center = radius / outer;
    final strength = math.pow(math.sin(math.pi * p), .6).toDouble();
    // A broad translucent front passes over live widgets; the file is above it.
    // Contract toward the sender's upper edge; expand from the receiver's bottom.
    canvas.drawCircle(
      origin,
      outer,
      Paint()
        ..shader = RadialGradient(
          colors: [
            TeraxColors.clear,
            colors.mint.withValues(alpha: strength * .12),
            colors.text.withValues(alpha: strength * .30),
            colors.mint.withValues(alpha: strength * .22),
            TeraxColors.clear,
          ],
          stops: [
            inner,
            inner + (center - inner) * .70,
            center,
            center + (1 - center) * .22,
            1,
          ],
        ).createShader(Rect.fromCircle(center: origin, radius: outer)),
    );
  }

  @override
  bool shouldRepaint(covariant _TransferWavePainter old) =>
      old.progress != progress ||
      old.incoming != incoming ||
      old.colors != colors;
}

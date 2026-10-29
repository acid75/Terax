import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/terax_theme.dart';

/// Ambient connection light. No file actor, expanding wave or desktop capture.
class ConnectionGlow extends StatefulWidget {
  const ConnectionGlow({
    super.key,
    required this.connected,
    required this.child,
    this.visible = true,
  });
  final bool connected, visible;
  final Widget child;
  @override
  State<ConnectionGlow> createState() => _ConnectionGlowState();
}

class _ConnectionGlowState extends State<ConnectionGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController breath;
  Timer? cycle;
  @override
  void initState() {
    super.initState();
    breath = AnimationController(
      vsync: this,
      duration: TeraxMotion.connectionGlow,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant ConnectionGlow old) {
    super.didUpdateWidget(old);
    sync();
  }

  void sync() {
    final animate =
        widget.connected &&
        widget.visible &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!animate) {
      cycle?.cancel();
      cycle = null;
      breath.stop();
      return;
    }
    if (cycle != null) return;
    breath.forward(from: 0);
    // A quiet interval between breaths avoids a permanently busy frame scheduler.
    cycle = Timer.periodic(
      TeraxMotion.connectionGlowCycle,
      (_) => breath.forward(from: 0),
    );
  }

  @override
  void dispose() {
    cycle?.cancel();
    breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (widget.connected && widget.visible)
        Positioned(
          top: MediaQuery.paddingOf(context).top,
          left: 0,
          right: 0,
          height: TeraxMotion.edgeZoneHeight * 2,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                key: const ValueKey('connection-glow'),
                child: AnimatedBuilder(
                  animation: breath,
                  builder: (context, _) => CustomPaint(
                    painter: _GlowPainter(
                      TeraxColors.of(context).mint,
                      MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : breath.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.color, this.phase);
  final Color color;
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final depth = size.height;
    final strength = .07 + .09 * math.pow(math.sin(math.pi * phase), 2);
    canvas.save();
    canvas.translate(size.width / 2, 0);
    canvas.scale(size.width / (depth * 1.6), 1);
    canvas.drawCircle(
      Offset.zero,
      depth,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: strength),
            color.withValues(alpha: strength * .45),
            TeraxColors.clear,
          ],
          stops: const [0, .42, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: depth)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.color != color || old.phase != phase;
}

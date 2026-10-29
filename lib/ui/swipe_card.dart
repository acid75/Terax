import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../theme/terax_theme.dart';

class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.enabled,
    required this.sending,
    required this.onSend,
    required this.child,
  });
  final bool enabled, sending;
  final VoidCallback onSend;
  final Widget child;
  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );
  bool _released = false;
  bool get _interactive => widget.enabled && !widget.sending && !_released;
  @override
  void didUpdateWidget(covariant SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.sending && oldWidget.sending) || !widget.enabled) {
      _position.stop();
      _position.value = 0;
      _released = false;
    }
  }

  void _return() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = 0;
      return;
    }
    // Physical constants specified in Movimiento.dc.html.
    _position.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: .85),
        _position.value,
        0,
        0,
      ),
    );
  }

  void _end(DragEndDetails details) {
    if (!_interactive) return;
    final height = context.size?.height ?? 0;
    final velocity = details.primaryVelocity ?? 0;
    if ((height > 0 &&
            -_position.value >= height * TeraxMotion.previewSwipeThreshold) ||
        velocity <= -TeraxMotion.previewSwipeVelocity) {
      setState(() => _released = true);
      HapticFeedback.lightImpact();
      if (!MediaQuery.disableAnimationsOf(context)) {
        _position.animateTo(
          -height,
          duration: TeraxMotion.previewExit,
          curve: TeraxMotion.exit,
        );
      }
      widget.onSend();
    } else {
      _return();
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Archivo para enviar. Desliza hacia arriba o usa el botón Enviar.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: !_interactive ? null : (_) => _position.stop(),
        onVerticalDragUpdate: !_interactive
            ? null
            : (details) {
                if (!_interactive) return;
                final height = context.size?.height ?? 0;
                _position.value = (_position.value + details.delta.dy).clamp(
                  -height,
                  0,
                );
              },
        onVerticalDragEnd: !_interactive ? null : _end,
        onVerticalDragCancel: !_interactive ? null : _return,
        child: AnimatedBuilder(
          animation: _position,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, reduced ? 0 : _position.value),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

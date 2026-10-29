import 'dart:math' as math;
import 'package:flutter/material.dart';

/// NameDrop reference: edge bloom, an expanding wave, then a quiet edge light.
/// Source layers: Figma 53:2759, 53:2758 and 53:2835 (local raster exports).
class EdgePortal extends StatefulWidget {
  const EdgePortal({
    super.key,
    required this.top,
    required this.active,
    this.progress = 0,
    this.label,
    this.expanded = false,
    this.timeline,
  });
  final bool top, active, expanded;
  final double progress;
  final String? label;
  final Animation<double>? timeline;
  @override
  State<EdgePortal> createState() => _EdgePortalState();
}

class _EdgePortalState extends State<EdgePortal>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool wasActive = false;
  @override
  void initState() {
    super.initState();
    pulse;
  }

  void sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = widget.active ? 1 : 0;
    } else if (widget.active && !wasActive && widget.timeline == null) {
      pulse.forward(from: 0);
    } else if (!widget.active) {
      pulse.stop();
      pulse.value = 0;
    }
    wasActive = widget.active;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant EdgePortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      height: widget.expanded ? null : 180,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: widget.timeline ?? pulse,
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              final t = widget.timeline?.value ?? pulse.value;
              final reduced = MediaQuery.disableAnimationsOf(context);
              final flash = math.sin(math.pi * t).clamp(0.0, 1.0);
              final w = box.maxWidth;
              final h = box.maxHeight;
              final span = math.min(w * 1.6, 1250.0);
              final ring = math.sqrt(w * w + h * h) * (.05 + 1.7 * t);
              final light = widget.active
                  ? (reduced ? .25 : .22 + flash * .78)
                  : 0.0;
              return ClipRect(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (widget.active)
                      Positioned.fill(
                        child: Transform.flip(
                          flipY: !widget.top,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: -span * .286,
                                left: (w - span) / 2,
                                width: span,
                                height: span * .64,
                                child: Opacity(
                                  opacity: light,
                                  child: Image.asset(
                                    'assets/motion/namedrop-light.png',
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -span * .188,
                                left: (w - span) / 2,
                                width: span,
                                height: span * .87,
                                child: Opacity(
                                  opacity: light * .25,
                                  child: Image.asset(
                                    'assets/motion/namedrop-bloom.png',
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                              if (!reduced && t > 0 && t < 1)
                                Positioned(
                                  top: -ring / 2,
                                  left: (w - ring) / 2,
                                  width: ring,
                                  height: ring,
                                  child: Opacity(
                                    opacity: (math.sin(math.pi * t) * .85)
                                        .clamp(0, 1),
                                    child: Image.asset(
                                      'assets/motion/namedrop-ripple.png',
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.label != null)
                      Align(
                        alignment: widget.top
                            ? const Alignment(0, .5)
                            : const Alignment(0, -.5),
                        child: Text(
                          widget.label!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

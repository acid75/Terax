import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/terax_theme.dart';
import 'transfer_wave.dart';

/// Launches one finite visual per acknowledged transfer in the root overlay.
/// [departureRect] uses global logical coordinates, including preview/drag origins.
class TransferFlight extends StatefulWidget {
  const TransferFlight({
    super.key,
    required this.child,
    required this.visual,
    required this.flightId,
    required this.active,
    this.departureRect,
    this.originKey,
    this.incoming = false,
    this.showcase = false,
  });
  final Widget child, visual;
  final String? flightId;
  final bool active;
  final bool incoming, showcase;
  final Rect? departureRect;
  final GlobalKey? originKey;
  @override
  State<TransferFlight> createState() => _TransferFlightState();
}

class _TransferFlightState extends State<TransferFlight>
    with TickerProviderStateMixin {
  final _source = GlobalKey();
  final _launched = <String>{};
  late final AnimationController _flight;
  late final AnimationController _wave;
  OverlayEntry? _waveEntry;
  @override
  void initState() {
    super.initState();
    _flight = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _remove();
      });
    _wave = AnimationController(vsync: this, duration: TeraxMotion.handoffWave)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _removeWave();
      });
  }

  void _removeWave() {
    _waveEntry?.remove();
    _waveEntry?.dispose();
    _waveEntry = null;
  }

  OverlayEntry? _entry;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TransferFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _remove() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _sync() {
    if (!widget.active || widget.flightId == null) {
      _generation++;
      _flight.stop();
      _wave.stop();
      _removeWave();
      _remove();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.stop();
      _removeWave();
    }
    final id = widget.flightId!;
    if (_launched.contains(id)) return;
    _launched.add(id);
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || !widget.active) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      final overlayBox = overlay?.context.findRenderObject();
      final sourceBox =
          (widget.originKey?.currentContext ?? _source.currentContext)
              ?.findRenderObject();
      if (overlay == null ||
          overlayBox is! RenderBox ||
          !overlayBox.hasSize ||
          (widget.departureRect == null &&
              (sourceBox is! RenderBox || !sourceBox.hasSize))) {
        return;
      }
      final global =
          widget.departureRect ??
          ((sourceBox as RenderBox).localToGlobal(Offset.zero) &
              sourceBox.size);
      if (global.isEmpty) return;
      final start = overlayBox.globalToLocal(global.topLeft) & global.size;
      final reduced = MediaQuery.disableAnimationsOf(context);
      final top = overlayBox
          .globalToLocal(Offset(0, MediaQuery.paddingOf(context).top))
          .dy;
      final incoming = widget.incoming;
      final bottom = overlayBox.size.height;
      _remove();
      _wave.stop();
      _removeWave();
      if (!reduced) {
        _waveEntry = OverlayEntry(
          builder: (_) => Positioned.fill(
            key: const ValueKey('transfer-wave-overlay'),
            child: InheritedTheme.captureAll(
              context,
              TransferWave(timeline: _wave, incoming: incoming),
            ),
          ),
        );
        overlay.insert(_waveEntry!);
        _wave.forward(from: 0);
      }
      _flight.duration = reduced
          ? TeraxMotion.interaction
          : widget.incoming
          ? widget.showcase
                ? TeraxMotion.handoffArrival
                : TeraxMotion.arrivalThumb
          : TeraxMotion.cancelReturn;
      _entry = OverlayEntry(
        builder: (_) => Positioned.fill(
          key: const ValueKey("transfer-flight-overlay"),
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flight,
              builder: (context, _) {
                final t = TeraxMotion.enter.transform(_flight.value);
                // Cross the physical window's safe top edge before shrinking away.
                final dy = reduced
                    ? start.top
                    : incoming
                    ? bottom +
                          (start.top - bottom) *
                              TeraxMotion.exit.transform(_flight.value)
                    : start.top + (top - start.height - start.top) * t;
                final arrivalT = TeraxMotion.exit.transform(_flight.value);
                final incomingWidth = math.max(
                  start.width,
                  TeraxSize.dragPreview,
                );
                final incomingHeight =
                    incomingWidth * start.height / start.width;
                final width = reduced || !incoming
                    ? start.width
                    : incomingWidth + (start.width - incomingWidth) * arrivalT;
                final height = reduced || !incoming
                    ? start.height
                    : incomingHeight +
                          (start.height - incomingHeight) * arrivalT;
                final left = reduced || !incoming
                    ? start.left
                    : (overlayBox.size.width - incomingWidth) / 2 +
                          (start.left -
                                  (overlayBox.size.width - incomingWidth) / 2) *
                              arrivalT;
                Rect pose = Rect.fromLTWH(left, dy, width, height);
                if (incoming && widget.showcase && !reduced) {
                  final width = math.min(
                    TeraxSize.handoffPreview,
                    overlayBox.size.width * .38,
                  );
                  final height = width * start.height / start.width;
                  final raised = Rect.fromCenter(
                    center: Offset(
                      overlayBox.size.width * .5,
                      overlayBox.size.height * .46,
                    ),
                    width: width,
                    height: height,
                  );
                  final below = Rect.fromLTWH(
                    (overlayBox.size.width - width) / 2,
                    bottom + TeraxSpace.s12,
                    width,
                    height,
                  );
                  final p = _flight.value;
                  pose = p < .62
                      ? Rect.lerp(
                          below,
                          raised,
                          Curves.easeOutCubic.transform((p / .62).clamp(0, 1)),
                        )!
                      : Rect.lerp(
                          raised,
                          start,
                          Curves.easeInOutCubic.transform(
                            ((p - .62) / .38).clamp(0, 1),
                          ),
                        )!;
                }
                final shrink = reduced || incoming
                    ? 1.0
                    : 1 - .6 * ((t - .65) / .35).clamp(0.0, 1.0);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: pose.left,
                      top: pose.top,
                      width: pose.width,
                      height: pose.height,
                      child: Opacity(
                        opacity: reduced
                            ? (incoming ? t : 1 - t)
                            : incoming
                            ? 1
                            : (1 - ((t - .85) / .15).clamp(0.0, 1.0)),
                        child: Transform.scale(
                          scale: shrink,
                          child: InheritedTheme.captureAll(
                            this.context,
                            widget.visual,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      overlay.insert(_entry!);
      _flight.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _generation++;
    _remove();
    _removeWave();
    _wave.dispose();
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _source, child: widget.child);
}

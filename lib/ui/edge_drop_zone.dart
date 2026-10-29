import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../library/library_service.dart';
import '../theme/terax_theme.dart';
import 'edge_motion.dart';

class EdgeDropZone extends StatelessWidget {
  const EdgeDropZone({
    super.key,
    required this.canAccept,
    required this.onDrop,
    this.destination,
    this.onDropPosition,
  });
  final bool canAccept;
  final ValueChanged<Offset>? onDropPosition;
  final String? destination;
  final ValueChanged<LibraryItem> onDrop;

  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final name = destination ?? 'El equipo';
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: TeraxMotion.edgeZoneHeight,
          child: DragTarget<LibraryItem>(
            onWillAcceptWithDetails: (_) {
              if (canAccept) HapticFeedback.lightImpact();
              return canAccept;
            },
            onAcceptWithDetails: (details) {
              if (canAccept) {
                onDropPosition?.call(details.offset);
                onDrop(details.data);
              }
            },
            builder: (context, candidates, rejected) => Stack(
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: candidates.isNotEmpty ? 1 : .25 / .55),
                    duration: TeraxMotion.zoneHover,
                    builder: (context, value, child) =>
                        Opacity(opacity: value, child: child),
                    child: EdgeMotion(
                      top: true,
                      timeline: const AlwaysStoppedAnimation(0),
                      active: canAccept,
                    ),
                  ),
                ),
                Positioned(
                  top: TeraxSpace.s64,
                  left: TeraxSpace.s16,
                  right: TeraxSpace.s16,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: TeraxSpace.s40,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TeraxSpace.s12,
                        vertical: TeraxSpace.s8,
                      ),
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(TeraxRadius.full),
                        border: Border.all(
                          color: canAccept ? c.mint : c.outline,
                        ),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              canAccept
                                  ? Icons.north_rounded
                                  : Icons.error_outline,
                              size: TeraxSize.iconSm,
                              color: canAccept ? c.mint : c.danger,
                            ),
                            const SizedBox(width: TeraxSpace.s8),
                            Flexible(
                              child: Text(
                                !canAccept
                                    ? '$name no responde'
                                    : candidates.isNotEmpty
                                    ? 'Suelta para enviar a $name'
                                    : 'Lleva aquí para enviar',
                                style: TeraxText.label.copyWith(color: c.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: TeraxSpace.s24,
          right: TeraxSpace.s24,
          bottom: TeraxSpace.s32,
          child: SafeArea(
            top: false,
            child: Text(
              'Suelta lejos del borde para cancelar',
              textAlign: TextAlign.center,
              style: TeraxText.caption.copyWith(color: c.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

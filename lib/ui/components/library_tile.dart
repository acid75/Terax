import 'package:flutter/material.dart';
import '../../theme/terax_theme.dart';
import 'focus_ring.dart';

enum TeraxTileState { ready, loading, unreadable }

class TeraxLibraryTile extends StatelessWidget {
  const TeraxLibraryTile({
    super.key,
    required this.name,
    this.thumbnail,
    this.onTap,
    this.folder = false,
    this.state = TeraxTileState.ready,
  });
  final String name;
  final Widget? thumbnail;
  final VoidCallback? onTap;
  final bool folder;
  final TeraxTileState state;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final face = TeraxThumbnail(state: state, folder: folder, child: thumbnail);
    return Semantics(
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: false,
      label: folder ? 'Abrir carpeta $name' : 'Vista previa de $name',
      child: Tooltip(
        triggerMode: TooltipTriggerMode.manual,
        message: name,
        child: TeraxFocusRing(
          radius: TeraxRadius.tile,
          child: Material(
            color: TeraxColors.clear,
            child: InkWell(
              excludeFromSemantics: true,
              onTap: onTap,
              borderRadius: BorderRadius.circular(TeraxRadius.tile),
              focusColor: c.mint.withValues(alpha: .2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(TeraxRadius.tile),
                      child: face,
                    ),
                  ),
                  const SizedBox(height: TeraxSpace.s4),
                  ExcludeSemantics(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TeraxText.tileName.copyWith(color: c.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TeraxThumbnail extends StatelessWidget {
  const TeraxThumbnail({
    super.key,
    this.state = TeraxTileState.ready,
    this.folder = false,
    this.child,
  });
  final TeraxTileState state;
  final bool folder;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    if (state == TeraxTileState.loading) return ColoredBox(color: c.surface);
    if (state == TeraxTileState.unreadable) {
      return Semantics(
        label: 'No se puede leer',
        child: ColoredBox(
          color: c.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = TeraxText.tileName.copyWith(color: c.textMuted);
              final text =
                  TextPainter(
                    text: TextSpan(text: 'No se puede leer', style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(
                    maxWidth: (constraints.maxWidth - TeraxSpace.s8).clamp(
                      0,
                      double.infinity,
                    ),
                  );
              final needed = TeraxSize.icon + TeraxSpace.s8 + text.height;
              text.dispose();
              if (constraints.maxHeight < needed) {
                return Icon(
                  Icons.broken_image_outlined,
                  color: c.textMuted,
                  size: TeraxSize.icon,
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: c.textMuted,
                    size: TeraxSize.icon,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(TeraxSpace.s4),
                    child: Text(
                      'No se puede leer',
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
    return child ??
        ColoredBox(
          color: c.surface,
          child: Center(
            child: Icon(
              folder ? Icons.folder_outlined : Icons.image_outlined,
              color: c.textMuted,
              size: TeraxSize.icon,
            ),
          ),
        );
  }
}

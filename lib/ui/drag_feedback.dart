import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../library/library_service.dart';
import '../theme/terax_theme.dart';

class DragFileFeedback extends StatelessWidget {
  const DragFileFeedback({super.key, required this.item, this.thumbnail});
  final LibraryItem item;
  final Widget? thumbnail;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: TeraxColors.clear,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduced ? Duration.zero : TeraxMotion.lift,
        curve: TeraxMotion.exit,
        builder: (context, value, child) => Transform.rotate(
          angle: reduced ? 0 : -3 * math.pi / 180 * value,
          child: Transform.scale(
            scale: reduced ? 1 : 1 + .08 * value,
            child: child,
          ),
        ),
        child: SizedBox(
          width: TeraxSize.dragPreview,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: TeraxSize.dragPreview,
                height: TeraxSize.dragPreview,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(TeraxRadius.tile),
                  border: Border.all(
                    color: c.mint,
                    width: TeraxSize.focusBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(TeraxSize.focusBorder),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(TeraxRadius.tile),
                    child:
                        thumbnail ??
                        Center(
                          child: Icon(
                            item.isImage
                                ? Icons.image_outlined
                                : Icons.description_outlined,
                            color: c.textMuted,
                            size: TeraxSize.iconLg,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: TeraxSpace.s8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TeraxText.labelSm.copyWith(color: c.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

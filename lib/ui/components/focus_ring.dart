import 'package:flutter/material.dart';
import '../../theme/terax_theme.dart';

/// One ring around the existing Material control; it adds no focus stop.
class TeraxFocusRing extends StatefulWidget {
  const TeraxFocusRing({
    super.key,
    required this.child,
    this.radius = TeraxRadius.lg,
  });
  final Widget child;
  final double radius;
  @override
  State<TeraxFocusRing> createState() => _TeraxFocusRingState();
}

class _TeraxFocusRingState extends State<TeraxFocusRing> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (value) {
      if (mounted) setState(() => focused = value);
    },
    child: Container(
      padding: const EdgeInsets.all(TeraxSpace.s2),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius + TeraxSpace.s2),
        border: Border.all(
          width: TeraxSize.focusBorder,
          color:
              focused &&
                  FocusManager.instance.highlightMode ==
                      FocusHighlightMode.traditional
              ? TeraxColors.of(context).mint
              : TeraxColors.clear,
        ),
      ),
      child: widget.child,
    ),
  );
}

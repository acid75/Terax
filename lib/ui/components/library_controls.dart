import 'package:flutter/material.dart';
import '../../theme/terax_theme.dart';
import 'focus_ring.dart';

class TeraxSegment<T> {
  const TeraxSegment({
    required this.value,
    required this.label,
    required this.icon,
  });
  final T value;
  final String label;
  final IconData icon;
}

class TeraxSegmentedControl<T> extends StatelessWidget {
  const TeraxSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    this.onChanged,
  });
  final List<TeraxSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final platform = TeraxPlatform.of(context);
    final s = TeraxSize.forPlatform(platform);
    final radius = platform == TeraxPlatform.android
        ? TeraxRadius.full
        : TeraxRadius.md;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TeraxSpace.s2),
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(
                child: Semantics(
                  selected: selected == segment.value,
                  child: TeraxFocusRing(
                    radius: radius,
                    child: Material(
                      color: selected == segment.value
                          ? c.accent
                          : TeraxColors.clear,
                      borderRadius: BorderRadius.circular(radius),
                      child: InkWell(
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(segment.value),
                        borderRadius: BorderRadius.circular(radius),
                        focusColor: c.mint.withValues(alpha: .2),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: s.segment),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TeraxSpace.s8,
                              vertical: TeraxSpace.s4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  segment.icon,
                                  size: TeraxSize.iconSm,
                                  color: selected == segment.value
                                      ? c.onAccent
                                      : c.text,
                                ),
                                const SizedBox(width: TeraxSpace.s8),
                                Flexible(
                                  child: Text(
                                    segment.label,
                                    textAlign: TextAlign.center,
                                    style: TeraxText.label.copyWith(
                                      color: selected == segment.value
                                          ? c.onAccent
                                          : c.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TeraxSearchField extends StatelessWidget {
  const TeraxSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClose,
    this.focusNode,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClose;
  final FocusNode? focusNode;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    autofocus: autofocus,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: TeraxText.body.copyWith(color: TeraxColors.of(context).text),
    decoration: InputDecoration(
      hintText: hint,
      isDense: true,
      prefixIcon: const Icon(Icons.search, size: TeraxSize.icon),
      suffixIcon: IconButton(
        tooltip: onClose == null ? 'Limpiar búsqueda' : 'Cerrar búsqueda',
        icon: const Icon(Icons.close_rounded, size: TeraxSize.icon),
        onPressed: () {
          controller.clear();
          onChanged('');
          onClose?.call();
        },
      ),
    ),
  );
}

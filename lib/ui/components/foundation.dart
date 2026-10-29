import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/terax_theme.dart';
import 'focus_ring.dart';

class TeraxBrand extends StatelessWidget {
  const TeraxBrand({super.key});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/branding/terax-wordmark.svg',
    height: TeraxSize.brandHeight,
    semanticsLabel: 'Terax',
  );
}

class TeraxPrimaryButton extends StatelessWidget {
  const TeraxPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.destructive = false,
    this.autofocus = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy, destructive, autofocus;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final size = TeraxSize.forPlatform(TeraxPlatform.of(context));
    return TeraxFocusRing(
      radius: size.buttonRadius,
      child: FilledButton(
        autofocus: autofocus,
        onPressed: busy ? null : onPressed,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(TeraxSize.minimumButtonWidth, size.button),
          ),
          backgroundColor: destructive
              ? WidgetStatePropertyAll(c.danger)
              : null,
          foregroundColor: destructive
              ? WidgetStatePropertyAll(c.onDanger)
              : null,
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              width: TeraxSize.focusBorder,
              color: states.contains(WidgetState.focused)
                  ? c.mint
                  : TeraxColors.clear,
            ),
          ),
        ),
        child: Semantics(
          liveRegion: busy,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: TeraxSize.spinner,
                  child: CircularProgressIndicator(
                    value: TeraxMotion.reduced(context) ? .5 : null,
                    strokeWidth: TeraxSize.focusBorder,
                    color: destructive ? c.onDanger : c.onMint,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: TeraxSize.iconSm),
              if (busy || icon != null) const SizedBox(width: TeraxSpace.s8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TeraxText.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeraxSwitchRow extends StatelessWidget {
  const TeraxSwitchRow({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.onChanged,
    this.compact = false,
    this.alignEnd = false,
  });
  final String title;
  final bool compact, alignEnd;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    void toggle() => onChanged?.call(!value);
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      focusable: onChanged != null,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      onTap: onChanged == null ? null : toggle,
      child: TeraxFocusRing(
        child: InkWell(
          excludeFromSemantics: true,
          onTap: onChanged == null ? null : toggle,
          borderRadius: BorderRadius.circular(TeraxRadius.lg),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? TeraxSpace.s4 : TeraxSpace.s12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: alignEnd
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                        style: (compact ? TeraxText.label : TeraxText.body)
                            .copyWith(color: c.text),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          textAlign: alignEnd
                              ? TextAlign.right
                              : TextAlign.left,
                          style: TeraxText.caption.copyWith(color: c.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: TeraxSpace.s12),
                ExcludeFocus(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TeraxEmptyState extends StatelessWidget {
  const TeraxEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.folder_open_outlined,
    this.actionLabel,
    this.onAction,
    this.loading = false,
    this.large = false,
    this.error = false,
  });
  final String title, message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading, large, error;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TeraxSpace.s16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TeraxSize.emptyWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading && !TeraxMotion.reduced(context))
                const SizedBox.square(
                  dimension: TeraxSize.emptyIcon,
                  child: CircularProgressIndicator(),
                )
              else if (TeraxPlatform.of(context) == TeraxPlatform.android)
                Container(
                  width: TeraxSize.emptyIconContainer,
                  height: TeraxSize.emptyIconContainer,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(TeraxRadius.sheet),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: TeraxSize.iconContainer,
                    color: error ? c.danger : c.mint,
                  ),
                )
              else
                Icon(
                  icon,
                  size: TeraxSize.emptyIcon,
                  color: error ? c.danger : c.mint,
                ),
              const SizedBox(height: TeraxSpace.s16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: (large ? TeraxText.display : TeraxText.headline)
                    .copyWith(color: c.text),
              ),
              const SizedBox(height: TeraxSpace.s12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TeraxText.bodyLg.copyWith(color: c.textMuted),
              ),
              if (actionLabel != null && onAction != null)
                Padding(
                  padding: const EdgeInsets.only(top: TeraxSpace.s24),
                  child: TeraxPrimaryButton(
                    label: actionLabel!,
                    onPressed: onAction,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showTeraxConfirmation(
  BuildContext context, {
  required String title,
  required String explanation,
  required String preservation,
  required String confirmLabel,
  IconData icon = Icons.link_off_rounded,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final c = TeraxColors.of(context);
        return AlertDialog(
          scrollable: true,
          semanticLabel: title,
          constraints: const BoxConstraints(maxWidth: TeraxSize.dialogWidth),
          icon: Icon(icon, color: c.danger, size: TeraxSize.iconLg),
          title: Text(title, style: TeraxText.headline.copyWith(color: c.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                explanation,
                style: TeraxText.body.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: TeraxSpace.s12),
              Text(
                preservation,
                style: TeraxText.label.copyWith(color: c.text),
              ),
            ],
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TeraxText.label),
            ),
            TeraxPrimaryButton(
              label: confirmLabel,
              icon: icon,
              destructive: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    ) ??
    false;

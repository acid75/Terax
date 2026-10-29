import 'package:flutter/material.dart';
import '../../theme/terax_theme.dart';
import 'focus_ring.dart';

enum TeraxDeviceStatus {
  unlinked,
  nearby,
  connected,
  reconnecting,
  unavailable,
}

class TeraxDeviceBar extends StatelessWidget {
  const TeraxDeviceBar({
    super.key,
    required this.name,
    required this.status,
    this.onTap,
    this.icon = Icons.desktop_windows_outlined,
    this.prompt = 'Enviar a',
  });
  final String name, prompt;
  final TeraxDeviceStatus status;
  final VoidCallback? onTap;
  final IconData icon;
  String get stateLabel => switch (status) {
    TeraxDeviceStatus.unlinked => 'Sin vincular',
    TeraxDeviceStatus.nearby => 'Cerca',
    TeraxDeviceStatus.connected => 'Conectado',
    TeraxDeviceStatus.reconnecting => 'Reconectando…',
    TeraxDeviceStatus.unavailable => 'Sin respuesta',
  };
  IconData get stateIcon => switch (status) {
    TeraxDeviceStatus.unlinked => Icons.add_link_rounded,
    TeraxDeviceStatus.nearby => Icons.check_rounded,
    TeraxDeviceStatus.connected => Icons.wifi_rounded,
    TeraxDeviceStatus.reconnecting => Icons.sync_rounded,
    TeraxDeviceStatus.unavailable => Icons.wifi_off_rounded,
  };
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final size = TeraxSize.forPlatform(TeraxPlatform.of(context));
    final near = status == TeraxDeviceStatus.nearby;
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TeraxSpace.s12,
        vertical: TeraxSpace.s4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TeraxRadius.full),
        border: Border.all(
          color: near ? c.mint : c.outline,
          width: TeraxSize.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            stateIcon,
            size: TeraxSize.iconSm,
            color: near ? c.mint : c.textMuted,
          ),
          const SizedBox(width: TeraxSpace.s4),
          Flexible(
            child: Text(
              stateLabel,
              maxLines: 2,
              style: TeraxText.label.copyWith(
                color: near ? c.mint : c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      onTap: onTap,
      enabled: onTap != null,
      label: '$prompt $name. $stateLabel',
      excludeSemantics: true,
      child: TeraxFocusRing(
        radius: size.cardRadius,
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(size.cardRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(size.cardRadius),
            focusColor: c.mint.withValues(alpha: .15),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.deviceCard),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TeraxSpace.s16,
                  vertical: TeraxSpace.s10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: TeraxSize.iconContainer,
                      height: TeraxSize.iconContainer,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.iconContainer,
                        border: Border.all(
                          color: c.iconRing,
                          width: TeraxSize.border,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: TeraxSize.icon,
                        color: c.iconOnContainer,
                      ),
                    ),
                    const SizedBox(width: TeraxSpace.s12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final label = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prompt,
                                style: TeraxText.caption.copyWith(
                                  color: c.textMuted,
                                ),
                              ),
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TeraxText.label.copyWith(color: c.text),
                              ),
                            ],
                          );
                          if (MediaQuery.textScalerOf(
                                    context,
                                  ).scale(TeraxText.label.fontSize!) >
                                  TeraxSize.icon ||
                              box.maxWidth < TeraxSize.tileMinimum * 2) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label,
                                const SizedBox(height: TeraxSpace.s8),
                                pill,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: label),
                              const SizedBox(width: TeraxSpace.s12),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: pill,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

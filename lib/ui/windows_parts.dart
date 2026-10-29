import '../sharing/shared_message.dart';
import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../theme/terax_theme.dart';
import 'components/focus_ring.dart';

String windowsType(String name, {bool directory = false}) {
  if (directory) return 'DIR';
  final extension = name.contains('.')
      ? name.split('.').last.toUpperCase()
      : 'ARCH';
  return switch (extension) {
    'DOCX' => 'DOC',
    'XLSX' => 'XLS',
    'PPTX' => 'PPT',
    _ => extension,
  };
}

String windowsTypeLabel(String name) => switch (windowsType(name)) {
  'DOC' => 'Word',
  'XLS' => 'Excel',
  'PPT' => 'PowerPoint',
  'TXT' => 'Texto',
  'MD' => 'Markdown',
  'ZIP' => 'Comprimido',
  'EXE' => 'Aplicación',
  _ => windowsType(name),
};

class WindowsTypeBadge extends StatelessWidget {
  const WindowsTypeBadge({
    super.key,
    required this.name,
    this.directory = false,
    this.size = TeraxSize.fileBadge,
  });
  final String name;
  final bool directory;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TeraxColors.windowsBadge,
        borderRadius: BorderRadius.circular(TeraxRadius.sm),
      ),
      child: Text(
        windowsType(name, directory: directory),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TeraxText.tileName.copyWith(color: c.textMuted),
      ),
    );
  }
}

class WindowsDeviceIndicator extends StatelessWidget {
  const WindowsDeviceIndicator({
    super.key,
    required this.controller,
    this.compact = false,
    this.onTap,
  });
  final AppController controller;
  final bool compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final linked = controller.peer != null;
    final name = controller.peer?.name ?? 'Sin teléfono vinculado';
    final online = controller.peerOnline && linked;
    final near =
        online && controller.nearbyFingerprint == controller.peer?.fingerprint;
    final status = online
        ? 'Conectado'
        : linked
        ? (controller.connecting ? 'Reconectando…' : 'Sin respuesta')
        : 'Sin vincular';
    if (compact) {
      return Tooltip(
        message: '$name · $status${near ? ' · Cerca' : ''}',
        child: TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: c.surface,
            foregroundColor: c.text,
            shape: const StadiumBorder(),
          ),
          onPressed: onTap,
          icon: Icon(
            online ? Icons.check_circle_outline : Icons.link_off,
            size: TeraxSize.iconSm,
            color: online ? c.mint : c.textMuted,
          ),
          label: Text(
            '$name · ${near ? 'Cerca' : status}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TeraxText.labelSm,
          ),
        ),
      );
    }
    return TeraxFocusRing(
      child: Material(
        color: TeraxColors.clear,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TeraxRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(TeraxSpace.s4),
            child: Row(
              children: [
                Container(
                  width: TeraxSize.iconContainer,
                  height: TeraxSize.iconContainer,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.iconContainer,
                    border: Border.all(color: c.iconRing),
                  ),
                  child: Icon(Icons.phone_android_outlined, color: c.text),
                ),
                const SizedBox(width: TeraxSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TeraxText.label,
                      ),
                      const SizedBox(height: TeraxSpace.s4),
                      Wrap(
                        spacing: TeraxSpace.s6,
                        runSpacing: TeraxSpace.s4,
                        children: [
                          _pill(
                            context,
                            status,
                            online ? Icons.check : Icons.link_off,
                            online,
                          ),
                          if (near)
                            _pill(context, 'Cerca', Icons.wifi_tethering, true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String title, IconData icon, bool active) {
    final c = TeraxColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TeraxSpace.s8,
        vertical: TeraxSpace.s2,
      ),
      decoration: BoxDecoration(
        color: active ? c.mint.withValues(alpha: .14) : c.surface,
        borderRadius: BorderRadius.circular(TeraxRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: TeraxSize.iconSm,
            color: active ? c.mint : c.textMuted,
          ),
          const SizedBox(width: TeraxSpace.s4),
          Flexible(
            child: Text(
              title,
              style: TeraxText.caption.copyWith(
                color: active ? c.mint : c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WindowsDocument extends StatelessWidget {
  const WindowsDocument({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    return Semantics(
      label: 'Representación del documento ${windowsType(name)}',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TeraxSize.paperWidth,
            maxHeight: TeraxSize.paperHeight,
          ),
          child: AspectRatio(
            aspectRatio: TeraxSize.paperWidth / TeraxSize.paperHeight,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Container(
                  padding: const EdgeInsets.all(TeraxSpace.s20),
                  decoration: BoxDecoration(
                    color: TeraxColors.documentPaper,
                    borderRadius: BorderRadius.circular(TeraxRadius.tile),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final fraction in [.7, 1.0, .92, .96])
                        Padding(
                          padding: const EdgeInsets.only(bottom: TeraxSpace.s8),
                          child: FractionallySizedBox(
                            widthFactor: fraction,
                            child: Container(
                              height: TeraxSpace.s4,
                              decoration: BoxDecoration(
                                color: TeraxColors.documentInk.withValues(
                                  alpha: .18,
                                ),
                                borderRadius: BorderRadius.circular(
                                  TeraxSpace.s4,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: -TeraxSpace.s10,
                  bottom: TeraxSpace.s18,
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: TeraxSize.paperWidth,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: TeraxSpace.s10,
                      vertical: TeraxSpace.s4,
                    ),
                    decoration: BoxDecoration(
                      color: c.onMint,
                      borderRadius: BorderRadius.circular(TeraxSpace.s6),
                    ),
                    child: Text(
                      windowsType(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TeraxText.monoSm.copyWith(color: c.mint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WindowsHistory extends StatelessWidget {
  const WindowsHistory({
    super.key,
    required this.entries,
    required this.onOpen,
    this.embedded = false,
  });
  final List<HistoryEntry> entries;
  final ValueChanged<HistoryEntry> onOpen;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    final items = entries.take(10).toList();
    final header = Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: TeraxSpace.s12,
      runSpacing: TeraxSpace.s4,
      children: [
        const Text('Historial', style: TeraxText.label),
        Text(
          'Guardado en este equipo',
          style: TeraxText.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
    final empty = Padding(
      padding: const EdgeInsets.symmetric(vertical: TeraxSpace.s32),
      child: Text(
        'Tus envíos completados y archivos recibidos aparecen aquí.',
        style: TeraxText.caption.copyWith(color: c.textMuted),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TeraxSpace.s20,
        vertical: TeraxSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: embedded ? MainAxisSize.min : MainAxisSize.max,
        children: [
          header,
          const SizedBox(height: TeraxSpace.s12),
          if (items.isEmpty)
            empty
          else if (embedded)
            for (final entry in items)
              Padding(
                padding: const EdgeInsets.only(bottom: TeraxSpace.s12),
                child: _entry(context, entry),
              )
          else
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, i) =>
                    const SizedBox(height: TeraxSpace.s12),
                itemBuilder: (_, i) => _entry(context, items[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, HistoryEntry entry) {
    final c = TeraxColors.of(context);
    final time =
        '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}';
    final image = [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
    ].contains(entry.name.split('.').last.toLowerCase());
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(TeraxRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(TeraxSpace.s10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(TeraxRadius.sm),
              child: SizedBox.square(
                dimension: TeraxSize.windowsRow,
                child: image
                    ? Image.file(
                        entry.file,
                        fit: BoxFit.cover,
                        cacheWidth: 88,
                        errorBuilder: (_, e, s) => WindowsTypeBadge(
                          name: SharedMessage.displayName(entry.name),
                          size: TeraxSize.windowsRow,
                        ),
                      )
                    : WindowsTypeBadge(
                        name: SharedMessage.displayName(entry.name),
                        size: TeraxSize.windowsRow,
                      ),
              ),
            ),
            const SizedBox(width: TeraxSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: SharedMessage.displayName(entry.name),
                    child: Text(
                      SharedMessage.displayName(entry.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TeraxText.labelSm,
                    ),
                  ),
                  Text(
                    '${entry.incoming ? '↙ Recibido' : '↗ Enviado'} · ${formatBytes(entry.size)} · $time',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TeraxText.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => onOpen(entry),
              child: const Text('Abrir'),
            ),
          ],
        ),
      ),
    );
  }
}

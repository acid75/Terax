import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../theme/terax_theme.dart';
import '../transfer/open_policy.dart';
import 'components/terax_components.dart';
import 'swipe_card.dart';
import 'message_composer.dart';

class AndroidFilePreview extends StatefulWidget {
  const AndroidFilePreview({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onSend,
    required this.onDestination,
    this.mediaKey,
  });
  final AppController controller;
  final GlobalKey? mediaKey;
  final VoidCallback onBack, onSend, onDestination;
  @override
  State<AndroidFilePreview> createState() => _AndroidFilePreviewState();
}

class _AndroidFilePreviewState extends State<AndroidFilePreview> {
  Future<String?>? dimensions;
  @override
  void initState() {
    super.initState();
    dimensions = _dimensions();
  }

  Future<String?> _dimensions() async {
    final file = widget.controller.selected;
    if (file == null ||
        autoOpenKind(widget.controller.selectedName ?? '') !=
            AutoOpenKind.image) {
      return null;
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return '${descriptor.width} × ${descriptor.height}';
    } catch (_) {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = TeraxColors.of(context);
    final name = c.selectedMessage?.label ?? c.selectedName ?? 'Archivo';
    final image = autoOpenKind(name) == AutoOpenKind.image;
    final visual = c.selectedMessage != null
        ? MessagePreview(message: c.selectedMessage!)
        : image && c.selected != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(TeraxSpace.s16),
            child: Image.file(
              c.selected!,
              fit: BoxFit.contain,
              cacheWidth: 1200,
              errorBuilder: (_, e, s) => _document(name),
            ),
          )
        : _document(name);
    final media = SwipeCard(
      enabled: c.canSend,
      sending: c.busy,
      onSend: widget.onSend,
      child: Padding(
        padding: const EdgeInsets.all(TeraxSpace.s20),
        child: Center(
          child: KeyedSubtree(key: widget.mediaKey, child: visual),
        ),
      ),
    );
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TeraxSpace.s20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(TeraxRadius.sheet),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TeraxText.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!image && c.selectedMessage == null)
            Text(
              'Representación del documento',
              style: TeraxText.caption.copyWith(color: colors.textMuted),
            ),
          FutureBuilder<String?>(
            future: dimensions,
            builder: (_, snapshot) => Text(
              '${formatBytes(c.selectedSize)}${snapshot.data == null ? '' : ' · ${snapshot.data}'}',
              style: TeraxText.monoSm.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(height: TeraxSpace.s16),
          Material(
            color: colors.bg,
            borderRadius: BorderRadius.circular(TeraxSpace.s16),
            child: InkWell(
              onTap: widget.onDestination,
              borderRadius: BorderRadius.circular(TeraxSpace.s16),
              child: Padding(
                padding: const EdgeInsets.all(TeraxSpace.s12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.iconContainer,
                      foregroundColor: colors.mint,
                      child: const Icon(Icons.desktop_windows_outlined),
                    ),
                    const SizedBox(width: TeraxSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.peer?.name ?? 'Conectar equipo',
                            style: TeraxText.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            c.peerOnline
                                ? (c.nearbyFingerprint == c.peer?.fingerprint
                                      ? 'Conectado · Cerca'
                                      : 'Conectado')
                                : 'Sin respuesta',
                            style: TeraxText.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      c.peerOnline ? Icons.check : Icons.link_off,
                      color: colors.mint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: TeraxSpace.s16),
          TeraxPrimaryButton(
            label: c.peerOnline
                ? 'Enviar a ${c.peer?.name ?? 'tu equipo'}'
                : 'Conectar equipo',
            icon: Icons.north_east,
            onPressed: c.busy ? null : widget.onSend,
          ),
          const SizedBox(height: TeraxSpace.s12),
          Text(
            image
                ? 'O desliza la foto hacia arriba'
                : 'O desliza el archivo hacia arriba',
            textAlign: TextAlign.center,
            style: TeraxText.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
    return ColoredBox(
      color: TeraxColors.previewBackground,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver a la biblioteca',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TeraxText.label,
                ),
              ),
              const SizedBox(width: TeraxSpace.s20),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, size) {
                final large =
                    MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
                    size.maxHeight < TeraxSize.emptyWidth;
                return large
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: TeraxSize.camera, child: media),
                            panel,
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Icon(
                            Icons.keyboard_double_arrow_up,
                            color: colors.mint,
                            size: TeraxSize.iconLg,
                          ),
                          Expanded(child: media),
                          panel,
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _document(String name) => ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: TeraxSize.documentWidth,
      maxHeight: TeraxSize.documentHeight,
    ),
    child: AspectRatio(
      aspectRatio: .76,
      child: Container(
        padding: const EdgeInsets.all(TeraxSpace.s28),
        decoration: BoxDecoration(
          color: TeraxColors.documentPaper,
          borderRadius: BorderRadius.circular(TeraxRadius.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.description_outlined,
              color: TeraxColors.documentInk,
              size: TeraxSize.emptyIcon,
            ),
            const Spacer(),
            Text(
              name.split('.').last.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TeraxText.headline.copyWith(
                color: TeraxColors.documentInk,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

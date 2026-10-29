import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_controller.dart';
import '../library/library_service.dart';
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';
import 'components/focus_ring.dart';
import 'settings.dart';
import 'windows_browser.dart';
import 'windows_parts.dart';
import 'transfer_scene.dart';
import 'history_page.dart';

class WindowsHome extends StatefulWidget {
  const WindowsHome({
    super.key,
    required this.controller,
    required this.library,
    required this.onSend,
    this.outbound = false,
    this.onDismiss,
    this.onIncomingDismiss,
    this.sharingActions,
    this.onRetry,
    this.departureRect,
    this.onDeparture,
    this.pendingName,
    this.pendingSize,
  });
  final AppController controller;
  final LibraryService library;
  final ValueChanged<LibraryItem> onSend;
  final bool outbound;
  final VoidCallback? onDismiss, onIncomingDismiss, onRetry;
  final Widget? sharingActions;
  final Rect? departureRect;
  final ValueChanged<Rect>? onDeparture;
  final String? pendingName;
  final int? pendingSize;
  @override
  State<WindowsHome> createState() => _WindowsHomeState();
}

class _WindowsHomeState extends State<WindowsHome> {
  bool sending = false;
  bool get showingSend =>
      (widget.outbound || sending) && c.incomingVisual == null;
  final scaffold = GlobalKey<ScaffoldState>();
  final browser = GlobalKey<WindowsBrowserState>();
  final customRoots = <LibraryItem>[];
  AppController get c => widget.controller;
  LibraryService get library => widget.library;
  bool get blocked =>
      c.starting ||
      c.connecting ||
      c.busy ||
      c.picking ||
      c.resettingLinks ||
      c.incoming != null;
  List<LibraryItem> get roots {
    final profile =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    final supplied = library.authorizedFolders;
    final locations = supplied.isEmpty
        ? [p.join(profile, 'Documents'), p.join(profile, 'Downloads')]
        : supplied.map((r) => r.location ?? r.id).toList();
    final pictures = p.join(profile, 'Pictures');
    if (!locations.contains(pictures)) locations.add(pictures);
    final entries = <String, LibraryItem>{
      for (final path in locations)
        path: LibraryItem(
          id: path,
          name: switch (p.basename(path)) {
            'Documents' => 'Documentos',
            'Downloads' => 'Descargas',
            'Pictures' => 'Imágenes',
            _ => p.basename(path),
          },
          isDirectory: true,
          isImage: false,
          size: 0,
          modified: DateTime.fromMillisecondsSinceEpoch(0),
          location: path,
        ),
      for (final root in customRoots) root.id: root,
    };
    return entries.values.toList();
  }

  void navigate(bool value) {
    setState(() => sending = value);
    scaffold.currentState?.closeDrawer();
  }

  Future<void> folder(LibraryItem root) async {
    if (blocked || library.loading) return;
    navigate(true);
    if (library.kind != LibraryKind.document) {
      await library.load(LibraryKind.document);
    }
    if (!mounted) return;
    await library.openAuthorizedFolder(root);
  }

  Future<void> addFolder() async {
    if (blocked || library.loading) return;
    navigate(true);
    await library.addFolder();
    if (!mounted) return;
    final path = library.currentLocation;
    if (path != null &&
        library.error == null &&
        !roots.any((r) => r.id == path)) {
      setState(
        () => customRoots.add(
          LibraryItem(
            id: path,
            name: p.basename(path),
            isDirectory: true,
            isImage: false,
            size: 0,
            modified: DateTime.fromMillisecondsSinceEpoch(0),
            location: path,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, library]),
    builder: (context, _) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (showingSend) browser.currentState?.focusSearch();
        },
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (showingSend) browser.currentState?.send();
        },
      },
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: LayoutBuilder(
          builder: (context, size) {
            final narrow = size.maxWidth < TeraxSize.desktopBreakpoint;
            final body = Column(
              children: [
                if (c.error != null &&
                    !widget.outbound &&
                    c.incomingVisual == null)
                  Material(
                    color: TeraxColors.of(context).surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TeraxSpace.s16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: TeraxColors.of(context).danger,
                          ),
                          const SizedBox(width: TeraxSpace.s8),
                          Expanded(
                            child: Text(
                              c.error!,
                              style: TeraxText.caption.copyWith(
                                color: TeraxColors.of(context).danger,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar mensaje',
                            onPressed: c.clearMessage,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: showingSend
                      ? WindowsBrowser(
                          key: browser,
                          controller: c,
                          library: library,
                          onSend: widget.onSend,
                          onDeparture: widget.onDeparture,
                          onSettings: () => showTeraxSettings(context, c),
                        )
                      : _receive(),
                ),
                if (widget.outbound)
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(TeraxSpace.s16),
                        child: TransferScene(
                          controller: c,
                          outbound: true,
                          compact: true,
                          docked: true,
                          onRetry: widget.onRetry,
                          departureRect: widget.departureRect,
                          autoDismiss: true,
                          pendingName: widget.pendingName,
                          pendingSize: widget.pendingSize,
                          onDismiss:
                              widget.onDismiss ??
                              () => c.dismissTransfer(received: false),
                        ),
                      ),
                    ),
                  ),
              ],
            );
            if (narrow) {
              return Scaffold(
                key: scaffold,
                appBar: AppBar(
                  leading: Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Abrir navegación',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                  ),
                  title: const TeraxBrand(),
                  backgroundColor: TeraxColors.of(context).bg,
                  surfaceTintColor: TeraxColors.clear,
                ),
                drawer: Drawer(
                  width: TeraxSize.sidebar,
                  backgroundColor: TeraxColors.of(context).bg,
                  child: _sidebar(),
                ),
                body: body,
              );
            }
            return Row(
              children: [
                SizedBox(width: TeraxSize.sidebar, child: _sidebar()),
                VerticalDivider(
                  width: TeraxSize.border,
                  color: TeraxColors.of(context).outline.withValues(alpha: .4),
                ),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    ),
  );
  Widget _sidebar() {
    final colors = TeraxColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TeraxSpace.s16,
        vertical: TeraxSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(
              left: TeraxSpace.s8,
              bottom: TeraxSpace.s28,
            ),
            child: Align(alignment: Alignment.centerLeft, child: TeraxBrand()),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _nav(
                    'Recibir',
                    Icons.south_west,
                    !showingSend,
                    () => navigate(false),
                  ),
                  const SizedBox(height: TeraxSpace.s4),
                  _nav(
                    'Enviar al teléfono',
                    Icons.north_east,
                    showingSend,
                    () => navigate(true),
                  ),
                  if (widget.sharingActions != null) widget.sharingActions!,
                  if (showingSend) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TeraxSpace.s12,
                        TeraxSpace.s28,
                        TeraxSpace.s12,
                        TeraxSpace.s6,
                      ),
                      child: Text(
                        'Carpetas',
                        style: TeraxText.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    for (final root in roots)
                      _nav(
                        root.name,
                        Icons.folder_outlined,
                        library.isRootActive(root),
                        blocked || library.loading ? null : () => folder(root),
                      ),
                    _nav(
                      'Agregar carpeta',
                      Icons.add,
                      false,
                      blocked || library.loading ? null : addFolder,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: TeraxSpace.s16),
          _nav(
            'Carpeta Recibidos',
            Icons.folder_open_outlined,
            false,
            c.server == null ? null : c.openFolder,
          ),
          _nav(
            'Equipos y ajustes',
            Icons.tune,
            false,
            () => showTeraxSettings(context, c),
          ),
        ],
      ),
    );
  }

  Widget _nav(String text, IconData icon, bool selected, VoidCallback? action) {
    final colors = TeraxColors.of(context);
    return TeraxFocusRing(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.standard,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: TeraxSpace.s12,
            vertical: TeraxSpace.s12,
          ),
          backgroundColor: selected ? colors.surface : TeraxColors.clear,
          foregroundColor: selected ? colors.mint : colors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TeraxRadius.lg),
          ),
        ),
        onPressed: action,
        icon: Icon(icon, size: TeraxSize.iconSm),
        label: Text(
          text,
          style: TeraxText.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _receive() {
    final colors = TeraxColors.of(context);
    final accepting = c.server?.accepting ?? false;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TeraxSpace.s28,
            vertical: TeraxSpace.s16,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.outline.withValues(alpha: .4)),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, size) {
              final device = WindowsDeviceIndicator(
                controller: c,
                onTap: () => showTeraxSettings(context, c),
              );
              final reception = TeraxSwitchRow(
                compact: true,
                alignEnd: true,
                title: c.server == null
                    ? (c.starting
                          ? 'Preparando recepción…'
                          : 'Recepción no disponible')
                    : accepting
                    ? 'Recepción activada'
                    : 'Recepción pausada',
                subtitle: c.autoOpenImages
                    ? 'Abrir al recibir: fotos y documentos'
                    : 'Abrir al recibir: desactivado',
                value: accepting,
                onChanged: blocked || c.server == null ? null : c.setAccepting,
              );
              return size.maxWidth < TeraxSize.splitBreakpoint ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? Column(children: [device, reception])
                  : Row(
                      children: [
                        Expanded(child: device),
                        const SizedBox(width: TeraxSpace.s24),
                        SizedBox(
                          width: TeraxSize.sidePanel + TeraxSpace.s40,
                          child: reception,
                        ),
                      ],
                    );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) {
              if (size.maxWidth < TeraxSize.splitBreakpoint) {
                return ListView(
                  children: [
                    SizedBox(
                      height: size.maxHeight.clamp(
                        TeraxSize.sidePanel,
                        TeraxSize.settingsWidth,
                      ),
                      child: _ready(),
                    ),
                    WindowsHistory(
                      entries: c.history,
                      onOpen: (e) =>
                          HistoryPage(controller: c).open(context, e),
                      embedded: true,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _ready()),
                  VerticalDivider(
                    width: TeraxSize.border,
                    color: colors.outline.withValues(alpha: .4),
                  ),
                  SizedBox(
                    width: TeraxSize.sidePanel,
                    child: WindowsHistory(
                      entries: c.history,
                      onOpen: (e) =>
                          HistoryPage(controller: c).open(context, e),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _receiptLocation(String path) {
    final parts = p.split(p.normalize(path));
    return parts
        .skip(parts.length > 3 ? parts.length - 3 : 0)
        .map((s) => s == 'Documents' ? 'Documentos' : s)
        .join(' › ');
  }

  Widget _ready() {
    if (c.incomingVisual != null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          child: TransferScene(
            controller: c,
            outbound: false,
            compact: true,
            docked: true,
            onDismiss:
                widget.onIncomingDismiss ??
                () => c.dismissTransfer(outgoing: false),
          ),
        ),
      );
    }
    final colors = TeraxColors.of(context);
    final accepting = c.server?.accepting ?? false;
    final title = c.starting
        ? 'Preparando recepción…'
        : c.server == null
        ? 'Conexión no disponible'
        : accepting
        ? 'Listo para recibir'
        : 'Recepción pausada';
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: TeraxSpace.s80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.lerp(colors.bg, colors.mint, .025)!, colors.bg],
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TeraxSpace.s32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: TeraxSize.readyIllustrationWidth,
                  height: TeraxSize.readyIllustrationHeight,
                  child: CustomPaint(painter: _ReceiveIllustration(colors)),
                ),
                const SizedBox(height: TeraxSpace.s24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TeraxText.display,
                ),
                const SizedBox(height: TeraxSpace.s12),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: TeraxSize.emptyWidth,
                  ),
                  child: Text(
                    c.server == null
                        ? 'Comprueba la conexión y vincula tu teléfono para recibir archivos.'
                        : !accepting
                        ? 'Activa la recepción para que tus equipos vinculados puedan enviarte archivos.'
                        : 'En tu teléfono, mantén presionado un archivo y llévalo arriba. Llega por aquí abajo.',
                    textAlign: TextAlign.center,
                    style: TeraxText.bodyLg.copyWith(color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: TeraxSpace.s24),
                if (c.server != null)
                  Text(
                    'Se guardan en ${_receiptLocation(c.server!.directory.path)}',
                    textAlign: TextAlign.center,
                    style: TeraxText.caption.copyWith(color: colors.textMuted),
                  ),
                if (!c.peerOnline)
                  TextButton.icon(
                    onPressed: blocked
                        ? null
                        : () => showTeraxSettings(context, c),
                    icon: const Icon(Icons.link),
                    label: const Text('Conectar equipo'),
                  ),
                if (c.server != null && !accepting)
                  TeraxPrimaryButton(
                    label: 'Activar recepción',
                    icon: Icons.south_west,
                    onPressed: blocked ? null : () => c.setAccepting(true),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiveIllustration extends CustomPainter {
  _ReceiveIllustration(this.colors);
  final TeraxColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 132, size.height / 96);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = TeraxSize.focusBorder
      ..color = colors.illustrationLine;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 10, 80, 54),
        const Radius.circular(6),
      ),
      line,
    );
    canvas.drawLine(const Offset(2, 72), const Offset(102, 72), line);
    canvas.save();
    canvas.translate(111, 58);
    canvas.rotate(-.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -28, 30, 56),
        const Radius.circular(7),
      ),
      line,
    );
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(58, 40)
        ..lineTo(70, 28)
        ..lineTo(60, 28)
        ..moveTo(70, 28)
        ..lineTo(70, 38),
      line..color = colors.mint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReceiveIllustration oldDelegate) =>
      oldDelegate.colors != colors;
}

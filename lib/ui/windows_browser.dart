import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_controller.dart';
import '../library/library_service.dart';
import '../theme/terax_theme.dart';
import '../transfer/protocol.dart' show maxFileBytes;
import 'components/terax_components.dart';
import 'windows_parts.dart';

class WindowsBrowser extends StatefulWidget {
  const WindowsBrowser({
    super.key,
    required this.controller,
    required this.library,
    required this.onSend,
    required this.onSettings,
    this.onDeparture,
  });
  final AppController controller;
  final LibraryService library;
  final ValueChanged<LibraryItem> onSend;
  final VoidCallback onSettings;
  final ValueChanged<Rect>? onDeparture;
  @override
  State<WindowsBrowser> createState() => WindowsBrowserState();
}

class WindowsBrowserState extends State<WindowsBrowser> {
  final mediaKey = GlobalKey();
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final tableFocus = FocusNode();
  final scroll = ScrollController();
  void focusSearch() => searchFocus.requestFocus();
  String? selectedId;
  String? location;
  @override
  void initState() {
    super.initState();
    location = library.currentLocation;
    library.addListener(_libraryChanged);
  }

  void _libraryChanged() {
    if (location == library.currentLocation || !mounted) return;
    location = library.currentLocation;
    setState(() {
      selectedId = null;
      search.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  AppController get c => widget.controller;
  LibraryService get library => widget.library;
  bool get blocked =>
      c.busy ||
      c.picking ||
      c.connecting ||
      c.starting ||
      c.resettingLinks ||
      c.incoming != null ||
      library.loading;
  List<LibraryItem> get visible => library.items
      .where((i) => i.name.toLowerCase().contains(search.text.toLowerCase()))
      .toList();
  LibraryItem? get selected =>
      visible.where((i) => i.id == selectedId).firstOrNull;
  double get rowHeight => math.max(
    TeraxSize.windowsRow,
    MediaQuery.textScalerOf(
          context,
        ).scale(TeraxText.label.fontSize! * TeraxText.label.height!) +
        TeraxSpace.s16,
  );
  @override
  void dispose() {
    library.removeListener(_libraryChanged);
    search.dispose();
    searchFocus.dispose();
    tableFocus.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send() {
    final item = selected;
    if (item == null ||
        item.isDirectory ||
        item.size > maxFileBytes ||
        blocked ||
        !c.peerOnline ||
        c.peer == null) {
      return;
    }
    final box = mediaKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      widget.onDeparture?.call(box.localToGlobal(Offset.zero) & box.size);
    }
    widget.onSend(item);
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (blocked || event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rows = visible;
    if (rows.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final old = rows.indexWhere((i) => i.id == selectedId);
      final next =
          (old < 0
                  ? 0
                  : old +
                        (event.logicalKey == LogicalKeyboardKey.arrowDown
                            ? 1
                            : -1))
              .clamp(0, rows.length - 1);
      setState(() => selectedId = rows[next].id);
      if (scroll.hasClients) {
        final offset = (next * rowHeight)
            .clamp(0.0, scroll.position.maxScrollExtent)
            .toDouble();
        if (TeraxMotion.reduced(context)) {
          scroll.jumpTo(offset);
        } else {
          scroll.animateTo(
            offset,
            duration: TeraxMotion.interaction,
            curve: Curves.easeOut,
          );
        }
      }
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isControlPressed &&
        selected?.isDirectory == true) {
      library.openFolder(selected!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, library]),
    builder: (context, _) {
      final colors = TeraxColors.of(context);
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.enter, control: true): send,
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TeraxSpace.s28,
                vertical: TeraxSpace.s20,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.outline.withValues(alpha: .4),
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, size) {
                  final field = TeraxSearchField(
                    controller: search,
                    focusNode: searchFocus,
                    hint: 'Buscar en ${library.locationLabel}',
                    onChanged: (_) => setState(() {}),
                  );
                  final device = WindowsDeviceIndicator(
                    controller: c,
                    compact: true,
                    onTap: widget.onSettings,
                  );
                  return size.maxWidth < TeraxSize.splitBreakpoint ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            field,
                            const SizedBox(height: TeraxSpace.s8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: device,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: field),
                            const SizedBox(width: TeraxSpace.s24),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: device,
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
            if (library.loading)
              LinearProgressIndicator(
                value: TeraxMotion.reduced(context) ? .5 : null,
                minHeight: TeraxSpace.s2,
              ),
            if (library.canGoBack && library.folderTrail.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: library.loading || blocked ? null : library.goBack,
                  icon: const Icon(Icons.chevron_left),
                  label: Text(
                    library.folderTrail.isEmpty
                        ? library.locationLabel
                        : library.folderTrail.join(' › '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, size) {
                  final panel = _preview(
                    compact: size.maxWidth < TeraxSize.splitBreakpoint,
                  );
                  if (size.maxWidth < TeraxSize.splitBreakpoint) {
                    return Column(
                      children: [
                        Expanded(child: _table()),
                        if (selected != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: size.maxHeight * .45,
                            ),
                            child: SingleChildScrollView(child: panel),
                          ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _table()),
                      VerticalDivider(
                        width: TeraxSize.border,
                        color: colors.outline.withValues(alpha: .4),
                      ),
                      SizedBox(
                        width: TeraxSize.sidePanel,
                        child: SingleChildScrollView(child: panel),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _table() {
    final colors = TeraxColors.of(context);
    final rows = visible;
    if (rows.isEmpty) {
      return TeraxEmptyState(
        title: library.loading
            ? 'Cargando archivos…'
            : library.error != null
            ? 'No se pudo abrir la carpeta'
            : search.text.isNotEmpty
            ? 'Sin coincidencias'
            : 'Esta carpeta está vacía',
        message:
            library.error ??
            (search.text.isNotEmpty
                ? 'Prueba con otro nombre.'
                : 'Elige una carpeta en el menú lateral.'),
        icon: library.error != null
            ? Icons.folder_off_outlined
            : Icons.folder_open_outlined,
        error: library.error != null,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TeraxSpace.s20,
        vertical: TeraxSpace.s12,
      ),
      child: LayoutBuilder(
        builder: (context, size) {
          final detailed =
              size.maxWidth >= TeraxSize.settingsWidth - TeraxSpace.s40 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.5;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TeraxSpace.s12,
                  vertical: TeraxSpace.s8,
                ),
                child: _columns(
                  const Text('Nombre', style: TeraxText.labelSm),
                  const Text('Tipo', style: TeraxText.labelSm),
                  const Text(
                    'Tamaño',
                    style: TeraxText.labelSm,
                    textAlign: TextAlign.right,
                  ),
                  const Text('Modificado', style: TeraxText.labelSm),
                  detailed: detailed,
                ),
              ),
              Expanded(
                child: Focus(
                  focusNode: tableFocus,
                  onFocusChange: (focused) {
                    if (focused &&
                        selectedId == null &&
                        rows.isNotEmpty &&
                        mounted) {
                      setState(() => selectedId = rows.first.id);
                    }
                  },
                  onKeyEvent: key,
                  child: ListView.builder(
                    controller: scroll,
                    itemExtent: rowHeight,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      final active = item.id == selectedId;
                      void select() {
                        if (blocked) return;
                        setState(() => selectedId = item.id);
                        tableFocus.requestFocus();
                      }

                      return Semantics(
                        button: true,
                        selected: active,
                        onTap: blocked ? null : select,
                        excludeSemantics: true,
                        label:
                            '${item.name}. ${item.isDirectory ? 'Carpeta' : formatBytes(item.size)}. ${active ? 'Seleccionado.' : ''}',
                        child: Listener(
                          onPointerDown: (event) {
                            if (event.buttons == 1) select();
                          },
                          child: Material(
                            color: active
                                ? colors.mint.withValues(alpha: .10)
                                : TeraxColors.clear,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                TeraxRadius.tile,
                              ),
                              side: BorderSide(
                                width: TeraxSize.focusBorder,
                                color: active ? colors.mint : TeraxColors.clear,
                              ),
                            ),
                            child: InkWell(
                              excludeFromSemantics: true,
                              canRequestFocus: false,
                              onTap: blocked ? null : select,
                              onDoubleTap: blocked || !item.isDirectory
                                  ? null
                                  : () => library.openFolder(item),
                              borderRadius: BorderRadius.circular(
                                TeraxRadius.tile,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: TeraxSpace.s12,
                                ),
                                child: _columns(
                                  Row(
                                    children: [
                                      WindowsTypeBadge(
                                        name: item.name,
                                        directory: item.isDirectory,
                                      ),
                                      const SizedBox(width: TeraxSpace.s10),
                                      Expanded(
                                        child: Tooltip(
                                          message: item.name,
                                          child: Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TeraxText.label.copyWith(
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    item.isDirectory
                                        ? 'Carpeta'
                                        : windowsTypeLabel(item.name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TeraxText.caption.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    item.isDirectory
                                        ? '—'
                                        : formatBytes(item.size),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TeraxText.monoSm.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    item.modified.millisecondsSinceEpoch <= 0
                                        ? '—'
                                        : '${item.modified.day}/${item.modified.month}/${item.modified.year}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TeraxText.caption.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  detailed: detailed,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _columns(
    Widget name,
    Widget type,
    Widget size,
    Widget date, {
    required bool detailed,
  }) => Row(
    children: [
      Expanded(child: name),
      const SizedBox(width: TeraxSpace.s12),
      if (detailed) ...[
        SizedBox(width: TeraxSize.tableType, child: type),
        const SizedBox(width: TeraxSpace.s12),
      ],
      SizedBox(width: TeraxSize.tableType, child: size),
      if (detailed) ...[
        const SizedBox(width: TeraxSpace.s12),
        SizedBox(width: TeraxSize.tableDate, child: date),
      ],
    ],
  );
  Widget _preview({required bool compact}) {
    final colors = TeraxColors.of(context);
    final item = selected;
    if (item == null) {
      return Padding(
        padding: const EdgeInsets.all(TeraxSpace.s24),
        child: Text(
          'Selecciona un archivo para verlo y enviarlo.',
          style: TeraxText.caption.copyWith(color: colors.textMuted),
        ),
      );
    }
    if (item.isDirectory) {
      return Padding(
        padding: const EdgeInsets.all(TeraxSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.folder_outlined,
              size: TeraxSize.emptyIcon,
              color: colors.textMuted,
            ),
            Text(item.name, style: TeraxText.headline),
            TextButton.icon(
              onPressed: blocked || library.loading
                  ? null
                  : () => library.openFolder(item),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Abrir carpeta'),
            ),
          ],
        ),
      );
    }
    final oversize = item.size > maxFileBytes;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TeraxSpace.s24,
        vertical: TeraxSpace.s28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Container(
              key: mediaKey,
              height: TeraxSize.camera + TeraxSpace.s20,
              padding: const EdgeInsets.all(TeraxSpace.s24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TeraxSpace.s16),
              ),
              child: item.isImage && item.localFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(TeraxRadius.sm),
                      child: Image.file(
                        item.localFile!,
                        fit: BoxFit.contain,
                        cacheWidth: 600,
                        errorBuilder: (_, e, s) => const TeraxEmptyState(
                          title: 'No se puede leer',
                          message:
                              'El archivo sigue disponible para comprobarlo.',
                          icon: Icons.broken_image_outlined,
                          error: true,
                        ),
                      ),
                    )
                  : WindowsDocument(name: item.name),
            ),
            const SizedBox(height: TeraxSpace.s16),
          ],
          Text(
            item.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TeraxText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: TeraxSpace.s4),
          Text(
            '${windowsType(item.name)} · ${formatBytes(item.size)}${item.modified.millisecondsSinceEpoch > 0 ? ' · ${item.modified.day}/${item.modified.month}/${item.modified.year}' : ''}',
            style: TeraxText.monoSm.copyWith(color: colors.textMuted),
          ),
          if (!item.isImage)
            Padding(
              padding: const EdgeInsets.only(top: TeraxSpace.s8),
              child: Text(
                'Representación del documento',
                style: TeraxText.caption.copyWith(color: colors.textMuted),
              ),
            ),
          const SizedBox(height: TeraxSpace.s16),
          TeraxPrimaryButton(
            label: 'Enviar a ${c.peer?.name ?? 'tu teléfono'}',
            icon: Icons.north_east,
            busy: c.picking,
            onPressed: oversize || blocked || !c.peerOnline || c.peer == null
                ? null
                : send,
          ),
          const SizedBox(height: TeraxSpace.s16),
          if (oversize)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: colors.danger,
                  size: TeraxSize.iconSm,
                ),
                const SizedBox(width: TeraxSpace.s8),
                Expanded(
                  child: Text(
                    'Pesa ${formatBytes(item.size)}. El máximo es 1 GB.',
                    style: TeraxText.caption.copyWith(color: colors.danger),
                  ),
                ),
              ],
            )
          else
            Text(
              c.peerOnline
                  ? 'Llega a Terax en el teléfono. Mantén la app abierta allá hasta que termine.'
                  : 'Conecta el teléfono para enviar. Abre Equipos y ajustes.',
              style: TeraxText.caption.copyWith(color: colors.textMuted),
            ),
          const SizedBox(height: TeraxSpace.s8),
          Text(
            'Ctrl+Enter para enviar · Ctrl+F para buscar',
            style: TeraxText.tileName.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

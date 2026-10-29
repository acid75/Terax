import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'drag_feedback.dart';
import 'ui_issue.dart';
import '../library/library_service.dart';
import '../app_controller.dart' show formatBytes;
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';

class LibraryBrowser extends StatefulWidget {
  const LibraryBrowser({
    super.key,
    required this.service,
    required this.onPreview,
    required this.canDrag,
    this.onDragging,
    this.onSend,
    this.destination,
    this.showControls = true,
    this.showHelp = true,
    this.sendingId,
  });
  final LibraryService service;
  final ValueChanged<LibraryItem> onPreview;
  final bool canDrag;
  final ValueChanged<bool>? onDragging;
  final ValueChanged<LibraryItem>? onSend;
  final String? destination, sendingId;
  final bool showControls, showHelp;
  @override
  State<LibraryBrowser> createState() => _LibraryBrowserState();
}

class _LibraryBrowserState extends State<LibraryBrowser>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = widget.service;
    if (state == AppLifecycleState.resumed &&
        mounted &&
        android &&
        service.kind == LibraryKind.photo &&
        !service.loading &&
        (service.photosDenied || service.photosLimited)) {
      service.load(LibraryKind.photo);
    }
  }

  final search = TextEditingController();
  String query = '';
  bool searching = false, showHint = true;
  final origins = <String, GlobalKey>{};
  final returns = <OverlayEntry>{};
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    for (final entry in returns) {
      entry.remove();
      entry.dispose();
    }
    returns.clear();
    super.dispose();
  }

  void switchKind(LibraryKind kind) {
    search.clear();
    setState(() => query = '');
    widget.service.load(kind);
  }

  bool get android => TeraxPlatform.of(context) == TeraxPlatform.android;
  TeraxColors get colors => TeraxColors.of(context);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final service = widget.service;
      final photos = service.kind == LibraryKind.photo;
      final visible = service.items
          .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      final tabs = TeraxSegmentedControl<LibraryKind>(
        segments: const [
          TeraxSegment(
            value: LibraryKind.photo,
            icon: Icons.photo_outlined,
            label: 'Fotos',
          ),
          TeraxSegment(
            value: LibraryKind.document,
            icon: Icons.description_outlined,
            label: 'Documentos',
          ),
        ],
        selected: service.kind,
        onChanged: switchKind,
      );
      final field = TeraxSearchField(
        controller: search,
        hint: photos ? 'Buscar fotos' : 'Buscar archivos',
        autofocus: android,
        onChanged: (v) => setState(() => query = v),
        onClose: android
            ? () {
                FocusScope.of(context).unfocus();
                setState(() => searching = false);
              }
            : null,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showControls) ...[
            if (android)
              searching
                  ? field
                  : Row(
                      children: [
                        Expanded(child: tabs),
                        const SizedBox(width: TeraxSpace.s8),
                        IconButton.filledTonal(
                          tooltip: photos ? 'Buscar fotos' : 'Buscar archivos',
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surface,
                            foregroundColor: colors.textMuted,
                          ),
                          onPressed: () => setState(() => searching = true),
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    )
            else ...[
              tabs,
              const SizedBox(height: TeraxSpace.s12),
              field,
            ],
            if (!photos) ...[
              const SizedBox(height: TeraxSpace.s12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final root in service.authorizedFolders)
                      Padding(
                        padding: const EdgeInsets.only(right: TeraxSpace.s8),
                        child: FilterChip(
                          selected: service.isRootActive(root),
                          showCheckmark: false,
                          selectedColor: colors.mint.withValues(alpha: .14),
                          backgroundColor: TeraxColors.clear,
                          side: BorderSide(
                            color: service.isRootActive(root)
                                ? colors.mint
                                : colors.outline,
                          ),
                          shape: const StadiumBorder(),
                          labelStyle: TeraxText.labelSm.copyWith(
                            color: service.isRootActive(root)
                                ? colors.mint
                                : colors.text,
                          ),
                          label: Text(
                            '${root.name}${_expired(root) ? ' · volver a autorizar' : ''}',
                          ),
                          avatar: _expired(root)
                              ? Icon(
                                  Icons.warning_amber_rounded,
                                  color: colors.danger,
                                  size: TeraxSize.iconSm,
                                )
                              : null,
                          onSelected: service.loading
                              ? null
                              : (_) => _expired(root)
                                    ? service.addFolder()
                                    : service.openAuthorizedFolder(root),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.create_new_folder_outlined,
                        size: TeraxSize.iconSm,
                      ),
                      label: const Text('Agregar carpeta'),
                      onPressed: service.loading ? null : service.addFolder,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (service.canGoBack)
                    IconButton(
                      tooltip: 'Volver a la carpeta anterior',
                      onPressed: service.loading ? null : service.goBack,
                      icon: const Icon(Icons.chevron_left),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TeraxSpace.s12,
                      ),
                      child: Text(
                        service.folderTrail.isEmpty
                            ? service.locationLabel
                            : service.folderTrail.join(' › '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TeraxText.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (service.photosLimited && photos)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    UiIssue.describe(UiIssueKind.partialPhotos).body,
                    style: TeraxText.caption.copyWith(color: colors.textMuted),
                  ),
                  TextButton(
                    onPressed: service.loading
                        ? null
                        : service.chooseMorePhotos,
                    child: const Text('Elegir más'),
                  ),
                ],
              ),
          ],
          if (service.loading && visible.isNotEmpty)
            LinearProgressIndicator(
              value: TeraxMotion.reduced(context) ? 0.5 : null,
              minHeight: TeraxSpace.s2,
            ),
          if (service.error != null && visible.isNotEmpty)
            _notice(service.error!),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: visible.isEmpty
                      ? _empty(service)
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notice) {
                            if (notice.metrics.extentAfter <
                                    TeraxSize.paginationDistance &&
                                service.hasMore &&
                                !service.loading &&
                                service.error == null &&
                                query.isEmpty) {
                              service.loadMore();
                            }
                            return false;
                          },
                          child: photos
                              ? _photos(visible)
                              : ListView.separated(
                                  padding: const EdgeInsets.only(
                                    bottom: TeraxSpace.s80,
                                  ),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, i) =>
                                      const SizedBox(height: TeraxSpace.s4),
                                  itemBuilder: (_, i) =>
                                      _item(visible[i], grid: false),
                                ),
                        ),
                ),
                if (android &&
                    widget.showHelp &&
                    showHint &&
                    visible.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: TeraxSpace.s8,
                    child: Material(
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(TeraxRadius.lg),
                        side: BorderSide(color: colors.outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: TeraxSpace.s16,
                          top: TeraxSpace.s8,
                          bottom: TeraxSpace.s8,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.north, color: colors.mint),
                            const SizedBox(width: TeraxSpace.s12),
                            Expanded(
                              child: Text(
                                photos
                                    ? 'Mantén presionada una foto y llévala arriba. O tócala para verla.'
                                    : 'Mantén presionado un archivo y llévalo arriba. O tócalo para verlo.',
                                style: TeraxText.caption,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar ayuda de gesto',
                              onPressed: () => setState(() => showHint = false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (service.hasMore)
            TextButton(
              onPressed: service.loading ? null : service.loadMore,
              child: const Text('Cargar más fotos'),
            ),
        ],
      );
    },
  );
  bool _expired(LibraryItem root) =>
      widget.service.isRootActive(root) &&
      (widget.service.error?.toLowerCase().contains('permiso') ?? false);
  Widget _photos(List<LibraryItem> items) {
    final groups = <String, List<LibraryItem>>{};
    for (final item in items) {
      groups.putIfAbsent(dayLabel(item.modified), () => []).add(item);
    }
    return LayoutBuilder(
      builder: (context, size) {
        final columns = android ? 3 : (size.maxWidth / 125).floor().clamp(3, 8);
        final width = (size.maxWidth - (columns - 1) * TeraxSpace.s4) / columns;
        return CustomScrollView(
          slivers: [
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: TeraxSpace.s16,
                    bottom: TeraxSpace.s12,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key, style: TeraxText.label)),
                      if (widget.showControls &&
                          entry.key == groups.keys.first &&
                          MediaQuery.textScalerOf(context).scale(1) < 1.5)
                        Text(
                          'Recientes primero',
                          style: TeraxText.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _item(entry.value[i], grid: true),
                  childCount: entry.value.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: TeraxSpace.s4,
                  mainAxisSpacing: TeraxSpace.s8,
                  mainAxisExtent:
                      width +
                      MediaQuery.textScalerOf(
                        context,
                      ).scale(TeraxSize.tileCaptionHeight) +
                      TeraxSpace.s8,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: TeraxSpace.s80)),
          ],
        );
      },
    );
  }

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TeraxSpace.s8),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: colors.danger),
        const SizedBox(width: TeraxSpace.s8),
        Expanded(
          child: Text(
            message,
            style: TeraxText.caption.copyWith(color: colors.danger),
          ),
        ),
      ],
    ),
  );
  Widget _empty(LibraryService service) {
    if (service.loading) {
      return const TeraxEmptyState(
        loading: true,
        title: 'Cargando biblioteca…',
        message: 'Un momento.',
        icon: Icons.photo_library_outlined,
      );
    }
    if (query.isNotEmpty) {
      return TeraxEmptyState(
        title: 'Sin coincidencias',
        message: service.hasMore
            ? 'Ningún archivo cargado coincide. Busca por nombre o carga más fotos.'
            : 'Ningún archivo coincide con ese nombre.',
        icon: Icons.search_off,
        actionLabel: 'Limpiar búsqueda',
        onAction: () {
          search.clear();
          setState(() => query = '');
        },
      );
    }
    final photos = service.kind == LibraryKind.photo;
    final denied =
        photos &&
        (service.photosDenied ||
            service.locationLabel != 'Tus fotos' &&
                service.photoAccess == null);
    return LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeraxEmptyState(
                title: denied
                    ? 'Terax necesita ver tus fotos'
                    : photos
                    ? 'Todavía no hay fotos'
                    : 'Tu biblioteca de archivos',
                message: denied
                    ? 'Para mostrarlas aquí y enviar las que elijas. Ninguna sale del teléfono hasta que tú la envías.'
                    : service.error ??
                          (photos
                              ? 'Las fotos de tu teléfono aparecerán aquí.'
                              : (android
                                    ? 'Agrega una carpeta para explorarla aquí. Para Descargas, usa Archivos.'
                                    : 'Agrega una carpeta una vez y explora sus archivos aquí.')),
                icon: photos
                    ? Icons.photo_library_outlined
                    : Icons.folder_open_outlined,
                actionLabel: denied
                    ? 'Permitir acceso a fotos'
                    : photos
                    ? null
                    : 'Agregar carpeta',
                onAction: denied
                    ? () => service.load(
                        LibraryKind.photo,
                        requestPermission: true,
                      )
                    : photos
                    ? null
                    : service.addFolder,
              ),
              if (denied && service.canChoosePhotos)
                TextButton(
                  onPressed: service.chooseMorePhotos,
                  child: const Text('Elegir solo algunas'),
                ),
              if (denied && service.photosDenied)
                TextButton(
                  onPressed: service.openPhotoSettings,
                  child: const Text('Abrir permisos de fotos'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(LibraryItem item, {required bool grid}) {
    void open() => item.isDirectory
        ? widget.service.openFolder(item)
        : widget.onPreview(item);
    final type = item.isDirectory
        ? 'DIR'
        : item.name.contains('.')
        ? item.name.split('.').last.toUpperCase()
        : 'ARCH';
    final face = grid
        ? TeraxLibraryTile(
            name: item.name,
            folder: item.isDirectory,
            thumbnail: _LibraryThumbnail(key: ValueKey(item.id), item: item),
            onTap: open,
          )
        : ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: TeraxSpace.s8,
            leading: Container(
              width: TeraxSize.touch,
              height: TeraxSize.touch,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TeraxRadius.lg),
              ),
              child: Text(
                type.length > 4 ? type.substring(0, 4) : type,
                style: TeraxText.monoSm.copyWith(color: colors.textMuted),
              ),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TeraxText.body,
            ),
            subtitle: Text(
              item.isDirectory
                  ? 'Carpeta'
                  : '$type · ${formatBytes(item.size)} · ${dayLabel(item.modified)}',
              style: TeraxText.caption.copyWith(color: colors.textMuted),
            ),
            trailing: item.isDirectory
                ? Icon(Icons.chevron_right, color: colors.textMuted)
                : null,
            onTap: open,
          );
    if (item.isDirectory) return face;
    final origin = origins.putIfAbsent(item.id, () => GlobalKey());
    final accessible = Semantics(
      customSemanticsActions: widget.onSend == null
          ? null
          : {
              CustomSemanticsAction(
                label: 'Enviar a ${widget.destination ?? 'tu equipo'}',
              ): () =>
                  widget.onSend!(item),
            },
      child: Stack(
        children: [
          face,
          if (widget.sendingId == item.id)
            Positioned(
              top: TeraxSpace.s4,
              right: TeraxSpace.s4,
              child: Semantics(
                label: 'Enviando este archivo',
                child: Container(
                  padding: const EdgeInsets.all(TeraxSpace.s4),
                  decoration: BoxDecoration(
                    color: colors.mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.mint),
                  ),
                  child: Icon(
                    Icons.north_east,
                    size: TeraxSize.iconSm,
                    color: colors.onMint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return KeyedSubtree(
      key: origin,
      child: LongPressDraggable<LibraryItem>(
        data: item,
        delay: TeraxMotion.longPress,
        maxSimultaneousDrags: widget.canDrag ? 1 : 0,
        onDragStarted: () {
          HapticFeedback.lightImpact();
          widget.onDragging?.call(true);
        },
        onDragEnd: (_) => widget.onDragging?.call(false),
        onDraggableCanceled: (_, offset) {
          widget.onDragging?.call(false);
          returnToCell(item, offset, origin);
        },
        feedback: DragFileFeedback(
          item: item,
          thumbnail: item.isImage ? _LibraryThumbnail(item: item) : null,
        ),
        childWhenDragging: Opacity(opacity: .3, child: face),
        child: accessible,
      ),
    );
  }

  void returnToCell(LibraryItem item, Offset offset, GlobalKey origin) {
    if (!mounted) return;
    final box = origin.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject();
    if (overlayBox is! RenderBox) return;
    final target = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final start = overlayBox.globalToLocal(offset);
    final reduced = TeraxMotion.reduced(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduced ? TeraxMotion.interaction : TeraxMotion.cancelReturn,
        curve: TeraxMotion.exit,
        onEnd: () {
          if (returns.remove(entry)) {
            entry.remove();
            entry.dispose();
          }
        },
        builder: (context, t, child) {
          final position = reduced ? target : Offset.lerp(start, target, t)!;
          return Positioned(
            left: position.dx,
            top: position.dy,
            child: IgnorePointer(
              child: Opacity(
                opacity: reduced ? 1 - t : 1 - (t - .8).clamp(0, .2) * 5,
                child: child,
              ),
            ),
          );
        },
        child: SizedBox.square(
          dimension: TeraxSize.dragPreview,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TeraxRadius.tile),
            child: item.isImage
                ? _LibraryThumbnail(item: item)
                : ColoredBox(
                    color: colors.surface,
                    child: Icon(
                      Icons.description_outlined,
                      color: colors.mint,
                      size: TeraxSize.iconLg,
                    ),
                  ),
          ),
        ),
      ),
    );
    returns.add(entry);
    overlay.insert(entry);
  }
}

String dayLabel(DateTime date) {
  if (date.millisecondsSinceEpoch <= 0) return 'Fecha no disponible';
  final now = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(date.toLocal());
  if (day == now) return 'Hoy';
  if (day == now.subtract(const Duration(days: 1))) return 'Ayer';
  return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
}

class _LibraryThumbnail extends StatefulWidget {
  const _LibraryThumbnail({super.key, required this.item});
  final LibraryItem item;
  @override
  State<_LibraryThumbnail> createState() => _LibraryThumbnailState();
}

class _LibraryThumbnailState extends State<_LibraryThumbnail> {
  late Future<Uint8List?> bytes;
  @override
  void initState() {
    super.initState();
    bytes = widget.item.thumbnail();
  }

  @override
  void didUpdateWidget(covariant _LibraryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.modified != widget.item.modified) {
      bytes = widget.item.thumbnail();
    }
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = TeraxThumbnail(state: TeraxTileState.loading);
    const unreadable = TeraxThumbnail(state: TeraxTileState.unreadable);
    if (widget.item.localFile != null) {
      return Image.file(
        widget.item.localFile!,
        fit: BoxFit.cover,
        cacheWidth: 400,
        errorBuilder: (_, error, stack) => unreadable,
      );
    }
    return FutureBuilder<Uint8List?>(
      future: bytes,
      builder: (context, snapshot) => snapshot.data == null
          ? snapshot.connectionState == ConnectionState.waiting
                ? placeholder
                : unreadable
          : Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, error, stack) => unreadable,
            ),
    );
  }
}

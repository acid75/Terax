import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../library/library_service.dart';
import 'edge_drop_zone.dart';
import 'library_browser.dart';
import 'pairing.dart';
import 'settings.dart';
import 'transfer_scene.dart';
import 'components/terax_components.dart';
import '../theme/terax_theme.dart';
import 'android_preview.dart';
import 'windows_home.dart';
import 'ui_issue.dart';
import '../sharing/android_share_bridge.dart';
import '../sharing/audio_access.dart';
import '../sharing/shared_message.dart';
import '../transfer/transfer_queue.dart';
import 'message_composer.dart';
import 'history_page.dart';
import 'queue_panel.dart';
import 'sharing_actions.dart';
import 'connection_glow.dart';

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.controller,
    this.library,
    this.chooseFiles,
    this.sharedContent,
  });
  final AppController controller;
  final LibraryService? library;
  final Future<List<LibraryItem>> Function()? chooseFiles;
  final Stream<SharedContent>? sharedContent;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final LibraryService library = widget.library ?? LibraryService();
  bool _dragging = false, _preview = false;
  bool _sendRequested = false, _fromEdge = false;
  bool _initialPairingShown = false;
  LibraryItem? _pendingItem;
  String? _sourceId;
  StreamSubscription<SharedContent>? _shareSubscription;
  String? _queuePeer, _queuePeerName;
  Rect? _departureRect;
  final _previewMediaKey = GlobalKey();
  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  late final TransferQueue queue = TransferQueue(
    send: _queuedSend,
    canStart: () =>
        !c.starting &&
        !c.connecting &&
        !c.resettingLinks &&
        !c.busy &&
        !c.picking &&
        c.peerOnline &&
        (_queuePeer == null || _queuePeer == c.peer?.fingerprint) &&
        c.incoming == null,
    cancelCurrent: c.cancel,
  );
  AppController get c => widget.controller;
  Future<QueueOutcome> _queuedSend(LibraryItem item) async {
    if (!mounted) return const QueueOutcome.cancelled();
    _departureRect = null;
    _queuePeer ??= c.peer?.fingerprint;
    _queuePeerName ??= c.peer?.name;
    setState(() {
      _pendingItem = item;
      _sourceId = item.id;
      _sendRequested = true;
      _preview = false;
      _fromEdge = false;
    });
    await c.sendLibraryItem(item);
    if (c.state == SendState.complete) return const QueueOutcome.sent();
    if (c.cancelRequested) return const QueueOutcome.cancelled();
    return QueueOutcome.failed(c.error ?? 'No se pudo confirmar el envío.');
  }

  void _retryOutgoing() {
    final job = queue.jobs
        .where(
          (job) =>
              (job.state == TransferJobState.failed ||
                  job.state == TransferJobState.pending) &&
              job.item.id == _pendingItem?.id,
        )
        .firstOrNull;
    if (job != null) {
      if (_queuePeer != null && _queuePeer != c.peer?.fingerprint) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La cola sigue dirigida a ${_queuePeerName ?? 'tu equipo original'}. Selecciónalo en ajustes.',
            ),
          ),
        );
        return;
      }
      if (job.state == TransferJobState.failed) {
        unawaited(queue.retry(job.id));
      } else {
        unawaited(queue.start());
      }
    } else {
      c.send();
    }
  }

  Future<void> _message({String? initial}) async {
    final value = await showMessageComposer(context, initial: initial);
    if (value == null || !mounted) return;
    try {
      final item = await c.createMessage(value);
      if (!mounted) return;
      if (TeraxPlatform.of(context) == TeraxPlatform.android &&
          !c.busy &&
          !c.picking &&
          !queue.running) {
        await _open(item);
      } else {
        await _confirmItems([item]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo preparar el mensaje: $e')),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final files = await (widget.chooseFiles?.call() ?? _chooseFiles());
      if (!mounted || files.isEmpty) return;
      if (TeraxPlatform.of(context) == TeraxPlatform.android &&
          files.length == 1 &&
          !c.busy &&
          !c.picking &&
          !queue.running) {
        await _open(files.single);
      } else {
        await _confirmItems(files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'No se pudo seleccionar el archivo. Intenta de nuevo.',
            ),
          ),
        );
      }
    }
  }

  Future<List<LibraryItem>> _chooseFiles() async {
    if (Platform.isAndroid) return AndroidShareBridge.pickFiles();
    final result = await FilePicker.pickFiles();
    return [
      for (final file in result)
        if (file.path != null)
          LibraryItem(
            id: file.path!,
            name: file.name,
            isDirectory: false,
            isImage: RegExp(
              r'\.(png|jpe?g|webp|gif|bmp)$',
              caseSensitive: false,
            ).hasMatch(file.name),
            size: await File(file.path!).length(),
            modified: DateTime.now(),
            localFile: File(file.path!),
          ),
    ];
  }

  Future<void> _confirmItems(List<LibraryItem> items) async {
    if (!mounted) return;
    final pending = queue.jobs.any(
      (job) =>
          job.state == TransferJobState.pending ||
          job.state == TransferJobState.sending ||
          job.state == TransferJobState.failed,
    );
    if (!pending) {
      _queuePeer = c.peer?.fingerprint;
      _queuePeerName = c.peer?.name;
    } else if (_queuePeer != null && _queuePeer != c.peer?.fingerprint) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La cola está preparada para ${_queuePeerName ?? 'otro equipo'}. Termínala o cancélala antes de cambiar de destino.',
          ),
        ),
      );
      return;
    }

    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Enviar ${items.length == 1 ? 'archivo' : '${items.length} archivos'}',
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: TeraxSize.camera,
            maxWidth: TeraxSize.emptyWidth,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(SharedMessage.displayName(item.name)),
                    subtitle: Text(formatBytes(item.size)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TeraxPrimaryButton(
            label: 'Añadir y enviar',
            icon: Icons.playlist_add,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      queue.add(items);
      unawaited(queue.start());
      if (!c.peerOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Archivos en cola. Conecta tu equipo y pulsa Continuar en la cola.',
            ),
          ),
        );
      }
    } on StateError catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _shared(SharedContent content) async {
    if (!mounted) return;
    if (content.warning != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(content.warning!)));
    }
    if (content.text != null && content.files.isNotEmpty) {
      final include = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Texto y archivos compartidos'),
          content: Text(
            'También hay texto o un enlace junto con ${content.files.length} archivo(s). Puedes incluirlo o enviar solo los archivos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Solo archivos'),
            ),
            TeraxPrimaryButton(
              label: 'Incluir texto',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (include == null || !mounted) return;
      if (!include) {
        await _confirmItems(content.files);
        return;
      }
      final message = await showMessageComposer(context, initial: content.text);
      if (message == null || !mounted) return;
      try {
        final item = await c.createMessage(message);
        if (mounted) await _confirmItems([item, ...content.files]);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo preparar el contenido compartido. Intenta de nuevo.',
              ),
            ),
          );
        }
      }
      return;
    }
    if (content.text != null) {
      await _message(initial: content.text);
    }
    if (!mounted || content.files.isEmpty) return;
    if (content.files.length == 1 && !c.busy && !c.picking && !queue.running) {
      await _open(content.files.single);
    } else {
      await _confirmItems(content.files);
    }
  }

  Future<void> _initialShared() async {
    try {
      final content = await AndroidShareBridge.takeInitial();
      if (content != null && mounted) await _shared(content);
    } catch (_) {}
  }

  void _sharingCommand(SharingCommand command) {
    switch (command) {
      case SharingCommand.history:
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => HistoryPage(controller: c)),
        );
      case SharingCommand.queue:
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TransferQueuePage(
              queue: queue,
              controller: c,
              destinationProvider: () => _queuePeer,
              destinationNameProvider: () => _queuePeerName,
            ),
          ),
        );
      case SharingCommand.sounds:
        unawaited(c.setTransferSounds(!c.sounds.enabled));
    }
  }

  Widget _sharingActions() => SharingActions(
    onFiles: _pickFiles,
    onMessage: () => _message(),
    onCommand: _sharingCommand,
    sounds: c.sounds.enabled,
    pending: queue.jobs
        .where(
          (j) =>
              j.state == TransferJobState.pending ||
              j.state == TransferJobState.sending ||
              j.state == TransferJobState.failed,
        )
        .length,
  );

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(AudioAccess.request(automatic: true));
      });
    }
    if (widget.library == null) _loadInitialLibrary();
    unawaited(c.loadHistory());
    if (widget.sharedContent != null) {
      _shareSubscription = widget.sharedContent!.listen((value) {
        unawaited(_shared(value));
      });
    } else if (Platform.isAndroid) {
      AndroidShareBridge.listen((content) {
        unawaited(_shared(content));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_initialShared());
      });
    }
  }

  Future<void> _loadInitialLibrary() async {
    await library.load(
      Platform.isWindows ? LibraryKind.document : LibraryKind.photo,
    );
    if (mounted &&
        Platform.isWindows &&
        library.currentLocation == null &&
        library.authorizedFolders.isNotEmpty) {
      await library.openAuthorizedFolder(library.authorizedFolders.first);
    }
  }

  @override
  void dispose() {
    unawaited(_shareSubscription?.cancel());
    if (Platform.isAndroid && widget.sharedContent == null) {
      AndroidShareBridge.stopListening();
    }
    queue.dispose();
    if (widget.library == null) library.dispose();
    super.dispose();
  }

  Future<void> _open(LibraryItem item) async {
    _sendRequested = false;
    _departureRect = null;
    _pendingItem = item;
    _sourceId = item.id;
    await c.selectLibraryItem(item);
    if (mounted && c.error == null && c.selected != null) {
      setState(() => _preview = true);
    }
  }

  void _send() {
    if (!c.canSend) {
      showConnectDialog(context, c);
      return;
    }
    if (_preview) _departureRect = _rect(_previewMediaKey);
    setState(() {
      _sendRequested = true;
      _preview = false;
      _fromEdge = false;
    });
    c.send();
  }

  void _drop(LibraryItem item) {
    setState(() {
      _dragging = false;
      _preview = false;
      _pendingItem = item;
      _sourceId = item.id;
      _sendRequested = true;
      _fromEdge = true;
    });
    c.sendLibraryItem(item);
  }

  void _dismissOutgoing() {
    if (c.busy) return;
    c.dismissTransfer(received: false);
    setState(() {
      _preview = false;
      _sendRequested = false;
      _fromEdge = false;
      _pendingItem = null;
      _sourceId = null;
    });
  }

  void _dismissIncoming() {
    c.dismissTransfer(outgoing: false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, library, queue]),
    builder: (context, _) {
      final outbound =
          c.busy ||
          c.outgoingId != null ||
          (_sendRequested && (c.picking || c.state == SendState.failed));
      final inbound = c.incomingVisual != null;
      return Scaffold(
        body: ConnectionGlow(
          connected: c.peerOnline && c.peer != null,
          visible: !c.busy && c.incoming == null,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (TeraxPlatform.of(context) == TeraxPlatform.android) {
                  if (!_initialPairingShown && !c.starting) {
                    _initialPairingShown = true;
                    if (c.knownPeers.isEmpty && c.peer == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) showConnectDialog(context, c);
                      });
                    }
                  }
                  return _android(outbound, inbound);
                }
                return WindowsHome(
                  controller: c,
                  library: library,
                  outbound: outbound,
                  onDismiss: _dismissOutgoing,
                  onRetry: _retryOutgoing,
                  sharingActions: _sharingActions(),
                  departureRect: _departureRect,
                  onDeparture: (rect) => _departureRect = rect,
                  onIncomingDismiss: _dismissIncoming,
                  pendingName: _pendingItem?.name,
                  pendingSize: _pendingItem?.size,
                  onSend: (item) {
                    setState(() {
                      _pendingItem = item;
                      _sourceId = item.id;
                      _sendRequested = true;
                      _fromEdge = false;
                    });
                    c.sendLibraryItem(item);
                  },
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _android(bool outbound, bool inbound) {
    final colors = TeraxColors.of(context);
    final transferring = outbound || inbound;
    return PopScope(
      canPop: !_preview && !library.canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_preview) {
            setState(() => _preview = false);
          } else if (library.canGoBack) {
            library.goBack();
          }
        }
      },
      child: Stack(
        children: [
          if (!_preview)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: TeraxSize.camera,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: .85,
                    colors: [colors.glow, colors.bg],
                  ),
                ),
              ),
            ),
          if (_preview && !transferring)
            Positioned.fill(
              child: AndroidFilePreview(
                controller: c,
                mediaKey: _previewMediaKey,
                onBack: () => setState(() => _preview = false),
                onSend: _send,
                onDestination: () => showTeraxSettings(context, c),
              ),
            )
          else
            Positioned.fill(
              child: Opacity(
                opacity: _dragging ? .28 : 1,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    transferring ? TeraxSpace.s12 : TeraxSpace.s20,
                    TeraxSpace.s12,
                    transferring ? TeraxSpace.s12 : TeraxSpace.s20,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: TeraxSize.androidHeader,
                          ),
                          child: _header(false),
                        ),
                        _sharingActions(),
                        if (c.error != null) _error(),
                        if (!transferring &&
                            library.kind == LibraryKind.photo &&
                            !library.photosDenied) ...[
                          _destination(),
                          const SizedBox(height: TeraxSpace.s12),
                        ],
                      ],
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: transferring ? TeraxSpace.s4 : 0,
                          ),
                          child: LibraryBrowser(
                            service: library,
                            onPreview: c.busy || c.picking || c.incoming != null
                                ? (_) {}
                                : _open,
                            destination: c.peer?.name,
                            showControls: !transferring,
                            showHelp: !transferring && !_dragging,
                            sendingId: c.busy || c.picking ? _sourceId : null,
                            onSend:
                                c.peerOnline &&
                                    !c.busy &&
                                    !c.picking &&
                                    c.incoming == null
                                ? (item) {
                                    _pendingItem = item;
                                    _sourceId = item.id;
                                    setState(() {
                                      _sendRequested = true;
                                      _fromEdge = false;
                                    });
                                    c.sendLibraryItem(item);
                                  }
                                : null,
                            canDrag:
                                c.peerOnline &&
                                !c.busy &&
                                !c.picking &&
                                c.incoming == null,
                            onDragging: (value) {
                              if (mounted) {
                                setState(() {
                                  _dragging = value;
                                  if (value) _departureRect = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      if (transferring)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .42,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TransferScene(
                                  key: ValueKey(
                                    outbound
                                        ? 'outgoing-transfer'
                                        : 'incoming-transfer',
                                  ),
                                  controller: c,
                                  outbound: outbound,
                                  compact: true,
                                  docked: true,
                                  autoDismiss: outbound,
                                  fromEdge: _fromEdge,
                                  onRetry: _retryOutgoing,
                                  departureRect: _departureRect,
                                  pendingName: _pendingItem?.name,
                                  pendingSize: _pendingItem?.size,
                                  onDismiss: outbound
                                      ? _dismissOutgoing
                                      : _dismissIncoming,
                                ),
                                if (outbound && inbound)
                                  TransferScene(
                                    key: const ValueKey('incoming-transfer'),
                                    controller: c,
                                    outbound: false,
                                    compact: true,
                                    docked: true,
                                    onDismiss: _dismissIncoming,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (_dragging && !transferring)
            Positioned.fill(
              child: EdgeDropZone(
                canAccept:
                    c.peerOnline && !c.busy && !c.picking && c.incoming == null,
                destination: c.peer?.name,
                onDrop: _drop,
                onDropPosition: (position) => _departureRect = Rect.fromLTWH(
                  position.dx,
                  position.dy,
                  TeraxSize.dragPreview,
                  TeraxSize.dragPreview,
                ),
              ),
            ),
          if (c.picking && !transferring)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: SizedBox.square(
                    dimension: TeraxSize.iconLg,
                    child: CircularProgressIndicator(
                      value: TeraxMotion.reduced(context) ? .5 : null,
                      strokeWidth: TeraxSize.focusBorder,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(bool desktop) {
    if (!desktop &&
        (library.kind == LibraryKind.document || library.photosDenied) &&
        TeraxPlatform.of(context) == TeraxPlatform.android) {
      final colors = TeraxColors.of(context);
      return Row(
        children: [
          const TeraxBrand(),
          const SizedBox(width: TeraxSpace.s12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.text,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => showTeraxSettings(context, c),
                icon: Icon(
                  c.peerOnline ? Icons.check_circle_outline : Icons.link_off,
                  size: TeraxSize.iconSm,
                ),
                label: Text(
                  '${c.peer?.name ?? 'Conectar equipo'} · ${c.peerOnline ? (c.nearbyFingerprint == c.peer?.fingerprint ? 'Cerca' : 'Conectado') : 'Sin respuesta'}',
                  style: TeraxText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        if (_preview)
          IconButton(
            tooltip: 'Volver a la biblioteca',
            onPressed: () => setState(() => _preview = false),
            icon: const Icon(Icons.arrow_back_rounded),
          )
        else
          const TeraxBrand(),
        const Spacer(),
        IconButton(
          tooltip: 'Ajustes y equipos',
          onPressed: () => showTeraxSettings(context, c),
          icon: const Icon(Icons.tune_rounded, size: TeraxSize.icon),
        ),
      ],
    );
  }

  Widget _destination() {
    final linked = c.peer != null;
    final status = c.peerOnline
        ? (c.nearbyFingerprint == c.peer?.fingerprint
              ? TeraxDeviceStatus.nearby
              : TeraxDeviceStatus.connected)
        : !linked
        ? TeraxDeviceStatus.unlinked
        : c.connecting || c.starting
        ? TeraxDeviceStatus.reconnecting
        : TeraxDeviceStatus.unavailable;
    return TeraxDeviceBar(
      name: c.peer?.name ?? 'Conectar equipo',
      status: status,
      onTap: c.connecting || c.starting
          ? null
          : () => linked
                ? showTeraxSettings(context, c)
                : showConnectDialog(context, c),
    );
  }

  Widget _error() {
    final issue = UiIssue.fromMessage(c.error!);
    final colors = TeraxColors.of(context);
    final refresh = issue.kind == UiIssueKind.missingFile;
    return Padding(
      padding: const EdgeInsets.only(bottom: TeraxSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: TeraxSize.iconSm,
                color: colors.danger,
              ),
              const SizedBox(width: TeraxSpace.s8),
              Expanded(
                child: Text(
                  issue.kind == UiIssueKind.connection
                      ? c.error!
                      : '${issue.title}. ${issue.body}',
                  style: TeraxText.caption.copyWith(color: colors.danger),
                ),
              ),
              IconButton(
                onPressed: c.clearMessage,
                tooltip: 'Cerrar mensaje',
                icon: const Icon(Icons.close, size: TeraxSize.iconSm),
              ),
            ],
          ),
          if (issue.action != null)
            TextButton(
              onPressed: refresh
                  ? () {
                      c.clearMessage();
                      library.load(library.kind);
                    }
                  : () => showTeraxSettings(context, c),
              child: Text(refresh ? 'Actualizar' : 'Equipos y ajustes'),
            ),
        ],
      ),
    );
  }
}

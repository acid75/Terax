import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';
import 'edge_motion.dart';
import 'transfer_view_state.dart';
import 'ui_issue.dart';
import 'settings.dart';
import 'windows_parts.dart';
import '../sharing/shared_message.dart';
import 'message_composer.dart';
import 'transfer_flight.dart';

class TransferScene extends StatefulWidget {
  const TransferScene({
    super.key,
    required this.controller,
    required this.outbound,
    this.fromEdge = false,
    required this.onDismiss,
    this.compact = false,
    this.autoDismiss = false,
    this.docked = false,
    this.pendingName,
    this.pendingSize,
    this.onRetry,
    this.departureRect,
  });
  final AppController controller;
  final bool outbound, fromEdge, compact, autoDismiss, docked;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;
  final Rect? departureRect;
  final String? pendingName;
  final int? pendingSize;
  @override
  State<TransferScene> createState() => _TransferSceneState();
}

class _TransferSceneState extends State<TransferScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController arrival;
  String? animatedId;
  final GlobalKey _departureKey = GlobalKey();
  Timer? dismissTimer, countdown;
  bool dismissalQueued = false;
  AppController get c => widget.controller;
  TransferViewState get view =>
      TransferViewState.from(c, outbound: widget.outbound);
  @override
  void initState() {
    super.initState();
    arrival = AnimationController(
      vsync: this,
      duration: TeraxMotion.arrivalWave,
    );
    c.addListener(changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant TransferScene old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      old.controller.removeListener(changed);
      c.addListener(changed);
    }
    sync();
  }

  void changed() {
    if (!mounted) return;
    sync();
    setState(() {});
  }

  void sync() {
    final state = view;
    final id = widget.outbound
        ? c.outgoingId
        : c.incomingVisual?.id ?? c.latestReceived?.id;
    final reduced = TeraxMotion.reduced(context);
    if (state.failed || state.stage == TransferViewStage.cancelled) {
      arrival.stop();
    } else if ((widget.outbound || c.incomingAnimationReady) &&
        id != null &&
        id != animatedId) {
      animatedId = id;
      dismissalQueued = false;
      dismissTimer?.cancel();
      arrival.duration = reduced
          ? TeraxMotion.interaction
          : TeraxMotion.arrivalWave;
      arrival.forward(from: 0);
    } else if (reduced &&
        arrival.isAnimating &&
        arrival.duration != TeraxMotion.interaction) {
      arrival.stop();
      arrival.value = 1;
    }
    if (widget.autoDismiss &&
        widget.outbound &&
        state.stage == TransferViewStage.sent &&
        !dismissalQueued) {
      dismissalQueued = true;
      final doneId = c.outgoingId;
      dismissTimer = Timer(const Duration(seconds: 2), () {
        if (mounted &&
            c.state == SendState.complete &&
            c.outgoingId == doneId &&
            !c.busy) {
          widget.onDismiss();
        }
      });
    }
    if (!state.success) {
      dismissalQueued = false;
      dismissTimer?.cancel();
      dismissTimer = null;
    }
    if (c.autoOpenDue != null) {
      countdown ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
    } else {
      countdown?.cancel();
      countdown = null;
    }
  }

  @override
  void dispose() {
    c.removeListener(changed);
    dismissTimer?.cancel();
    countdown?.cancel();
    arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = view;
    final message = widget.outbound
        ? c.selectedMessage
        : c.receiveComplete
        ? c.receivedMessage
        : null;
    final name =
        message?.label ??
        (widget.outbound
            ? (c.picking ? widget.pendingName : null) ??
                  c.selectedName ??
                  widget.pendingName ??
                  'Archivo'
            : c.incomingVisual?.name ?? c.latestReceived?.name ?? 'Archivo');
    final size = widget.outbound
        ? (c.picking ? widget.pendingSize : null) ?? c.selectedSize
        : c.incomingVisual?.total ?? c.latestReceived?.size ?? 0;
    final preview = widget.outbound
        ? c.outgoingPreview
        : c.receiveComplete
        ? null
        : c.incomingPreview;
    final file = widget.outbound
        ? c.selected
        : c.receiveComplete
        ? c.latestReceived?.file
        : null;
    final object = TransferFileVisual(
      name: name,
      file: file,
      preview: preview,
      message: message,
    );
    final card = widget.docked
        ? _dock(context, state, name, size, preview, file)
        : _card(context, state, name, size, preview, file);
    Widget departure(Widget child) => TransferFlight(
      flightId: c.outgoingId,
      active:
          widget.outbound &&
          !state.failed &&
          state.stage != TransferViewStage.cancelled,
      departureRect: widget.departureRect,
      originKey: _departureKey,
      visual: widget.departureRect == null
          ? TransferFileVisual(
              name: name,
              file: file,
              preview: preview,
              message: message,
              small: true,
            )
          : object,
      child: child,
    );
    if (widget.compact) {
      if (widget.outbound) return departure(card);
      return TransferFlight(
        flightId: c.incomingVisual?.id ?? c.latestReceived?.id,
        active:
            c.incomingAnimationReady &&
            !state.failed &&
            state.stage != TransferViewStage.cancelled,
        incoming: true,
        showcase: widget.docked,
        originKey: _departureKey,
        visual: TransferFileVisual(
          name: name,
          file: file,
          preview: preview,
          message: message,
          small: true,
        ),
        child: card,
      );
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final objectHeight = math.min(
          TeraxSize.arrivalHeight,
          bounds.maxHeight * .48,
        );
        final content = Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!widget.outbound)
              SizedBox(
                height: largeText ? TeraxSize.dragPreview : objectHeight,
                child: AnimatedBuilder(
                  animation: arrival,
                  child: Align(
                    child: SizedBox(
                      width: largeText
                          ? TeraxSize.dragPreview
                          : TeraxSize.arrivalWidth,
                      height: largeText ? TeraxSize.dragPreview : objectHeight,
                      child: object,
                    ),
                  ),
                  builder: (context, child) {
                    final t =
                        (arrival.value /
                                (TeraxMotion.arrivalThumb.inMilliseconds /
                                    TeraxMotion.arrivalWave.inMilliseconds))
                            .clamp(0.0, 1.0);
                    final moving =
                        animatedId != null &&
                        !TeraxMotion.reduced(context) &&
                        !state.failed &&
                        state.stage != TransferViewStage.cancelled;
                    return Transform.translate(
                      offset: Offset(
                        0,
                        moving
                            ? (widget.outbound
                                  ? -bounds.maxHeight * t
                                  : bounds.maxHeight *
                                        (1 - TeraxMotion.exit.transform(t)))
                            : 0,
                      ),
                      child: Opacity(
                        key: const ValueKey('transfer-object-opacity'),
                        opacity: !widget.outbound && !c.incomingAnimationReady
                            ? 0
                            : widget.outbound && moving
                            ? 1 - t
                            : 1,
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: TeraxSpace.s20),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TeraxSize.transferCardWidth,
              ),
              child: widget.outbound ? departure(card) : card,
            ),
          ],
        );
        return Stack(
          children: [
            Positioned.fill(
              child: EdgeMotion(
                top: widget.outbound,
                timeline: arrival,
                active:
                    animatedId != null &&
                    !state.failed &&
                    state.stage != TransferViewStage.cancelled,
                failed: state.failed,
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  TeraxSpace.s20,
                  TeraxSpace.s20,
                  TeraxSpace.s20,
                  TeraxSpace.s56,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (bounds.maxHeight - TeraxSpace.s20 - TeraxSpace.s56)
                            .clamp(0, double.infinity),
                  ),
                  child: content,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(
    BuildContext context,
    TransferViewState state,
    String name,
    int size,
    Uint8List? preview,
    File? file,
  ) {
    final colors = TeraxColors.of(context);
    final cancel = widget.outbound && c.busy && c.progress < 1;
    final received = state.stage == TransferViewStage.received;
    final issue = UiIssue.fromMessage(state.message ?? '');
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TeraxRadius.transferCard),
          side: BorderSide(
            color: state.failed ? colors.danger : colors.outline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(TeraxSpace.s16),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final stacked =
                  MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
                  bounds.maxWidth < TeraxSize.camera;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.compact) ...[
                        SizedBox.square(
                          key: _departureKey,
                          dimension: TeraxSize.touch,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              TeraxRadius.tile,
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: TransferFileVisual(
                                    name: name,
                                    preview: preview,
                                    file: file,
                                    small: true,
                                    message: widget.outbound
                                        ? c.selectedMessage
                                        : c.receiveComplete
                                        ? c.receivedMessage
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: TeraxSize.icon,
                                    height: TeraxSize.icon,
                                    decoration: BoxDecoration(
                                      color: state.failed
                                          ? colors.danger
                                          : colors.mint,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      state.success ? Icons.check : state.icon,
                                      size: TeraxSize.iconSm,
                                      color: colors.onMint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: TeraxSpace.s12),
                      ] else ...[
                        if (widget.outbound)
                          SizedBox.square(
                            key: _departureKey,
                            dimension: TeraxSize.touch,
                            child: TransferFileVisual(
                              name: name,
                              preview: preview,
                              file: file,
                              small: true,
                              message: c.selectedMessage,
                            ),
                          )
                        else
                          Container(
                            width: TeraxSize.iconLg,
                            height: TeraxSize.iconLg,
                            decoration: BoxDecoration(
                              color: state.success
                                  ? colors.mint
                                  : TeraxColors.clear,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              state.success ? Icons.check : state.icon,
                              size: TeraxSize.iconSm,
                              color: state.success
                                  ? colors.onMint
                                  : state.failed
                                  ? colors.danger
                                  : colors.mint,
                            ),
                          ),
                        const SizedBox(width: TeraxSpace.s12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    state.title,
                                    style: TeraxText.label.copyWith(
                                      color: state.failed
                                          ? colors.danger
                                          : colors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: TeraxSpace.s4),
                            Text(
                              received && !widget.compact
                                  ? '$name · ${formatBytes(size)}${c.incomingSourceName == null ? '' : ' · desde ${c.incomingSourceName}'}'
                                  : name,
                              maxLines: widget.compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TeraxText.caption.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (received)
                        IconButton(
                          tooltip: 'Volver a recibir',
                          onPressed: c.incoming != null
                              ? null
                              : widget.onDismiss,
                          icon: const Icon(Icons.close, size: TeraxSize.iconSm),
                        ),
                      if (cancel && !stacked)
                        TextButton(
                          onPressed: c.cancel,
                          child: const Text('Cancelar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: TeraxSpace.s12),
                  if (!state.done)
                    Semantics(
                      label: state.title,
                      value: '${(state.progress * 100).floor()}%',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(TeraxRadius.full),
                        child: LinearProgressIndicator(
                          value: state.progress,
                          minHeight: TeraxSpace.s6,
                          backgroundColor: colors.bg,
                        ),
                      ),
                    ),
                  if (!state.done) ...[
                    const SizedBox(height: TeraxSpace.s8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: TeraxSpace.s12,
                      runSpacing: TeraxSpace.s4,
                      children: [
                        Text(
                          '${formatBytes((state.progress * size).floor())} de ${formatBytes(size)}',
                          style: TeraxText.monoSm.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        if (widget.outbound)
                          Text(
                            'Mantén Terax abierto hasta que termine',
                            style: TeraxText.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (state.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: TeraxSpace.s12),
                      child: Text(
                        state.failed &&
                                issue.kind != UiIssueKind.connection &&
                                state.stage != TransferViewStage.integrityError
                            ? issue.body
                            : state.message!,
                        style: TeraxText.caption.copyWith(
                          color: state.failed
                              ? colors.danger
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  if (cancel && stacked)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: c.cancel,
                        child: const Text('Cancelar'),
                      ),
                    ),
                  if (state.done)
                    received
                        ? _receivedActions(context, bounds.maxWidth)
                        : Wrap(
                            spacing: TeraxSpace.s12,
                            runSpacing: TeraxSpace.s4,
                            children: [
                              if (widget.outbound &&
                                  (state.failed ||
                                      state.stage ==
                                          TransferViewStage.cancelled))
                                TextButton.icon(
                                  onPressed: c.canSend && c.incoming == null
                                      ? (widget.onRetry ?? c.send)
                                      : null,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                              if (state.failed)
                                TextButton(
                                  onPressed: () =>
                                      showTeraxSettings(context, c),
                                  child: const Text('Equipos y ajustes'),
                                ),
                              TextButton(
                                onPressed:
                                    (widget.outbound
                                        ? c.busy
                                        : c.incoming != null)
                                    ? null
                                    : widget.onDismiss,
                                child: const Text('Listo'),
                              ),
                            ],
                          ),
                  if (received && widget.compact && c.receivedMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: TeraxSpace.s12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: TeraxSize.camera,
                        ),
                        child: SingleChildScrollView(
                          child: MessagePreview(message: c.receivedMessage!),
                        ),
                      ),
                    ),
                  if (received &&
                      (c.openingFailure ?? c.automaticOpenNotice) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: TeraxSpace.s8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: TeraxSize.iconSm,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: TeraxSpace.s8),
                          Expanded(
                            child: Text(
                              (c.openingFailure ?? c.automaticOpenNotice)!,
                              style: TeraxText.caption.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dock(
    BuildContext context,
    TransferViewState state,
    String name,
    int size,
    Uint8List? preview,
    File? file,
  ) {
    final colors = TeraxColors.of(context);
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final received = state.stage == TransferViewStage.received;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        key: const ValueKey('transfer-dock'),
        color: colors.surface,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outline)),
          ),
          padding: const EdgeInsets.all(TeraxSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    key: _departureKey,
                    dimension: TeraxSize.touch,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(TeraxRadius.tile),
                      child: TransferFileVisual(
                        name: name,
                        file: file,
                        preview: preview,
                        small: true,
                        message: widget.outbound
                            ? c.selectedMessage
                            : c.receivedMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: TeraxSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.icon,
                              size: TeraxSize.iconSm,
                              color: state.failed ? colors.danger : colors.mint,
                            ),
                            const SizedBox(width: TeraxSpace.s6),
                            Expanded(
                              child: Text(
                                state.title,
                                style: TeraxText.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: TeraxSpace.s4),
                        Text(
                          '$name · ${formatBytes(size)}',
                          style: TeraxText.caption.copyWith(
                            color: colors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!state.done)
                    Padding(
                      padding: const EdgeInsets.only(left: TeraxSpace.s8),
                      child: Text(
                        '${(state.progress * 100).floor()}%',
                        style: TeraxText.monoSm,
                      ),
                    ),
                  if (!stacked && widget.outbound && c.busy && c.progress < 1)
                    TextButton(
                      onPressed: c.cancel,
                      child: const Text('Cancelar'),
                    ),
                  if (state.done)
                    IconButton(
                      tooltip: 'Cerrar transferencia',
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (stacked && widget.outbound && c.busy && c.progress < 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: c.cancel,
                    child: const Text('Cancelar'),
                  ),
                ),
              if (!state.done)
                Padding(
                  padding: const EdgeInsets.only(top: TeraxSpace.s8),
                  child: LinearProgressIndicator(
                    value:
                        state.stage == TransferViewStage.preparingSend ||
                            state.stage == TransferViewStage.preparingReceive
                        ? null
                        : state.progress,
                    minHeight: TeraxSize.focusBorder,
                    backgroundColor: colors.bg,
                  ),
                ),
              if (state.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: TeraxSpace.s8),
                  child: Text(
                    state.message!,
                    style: TeraxText.caption.copyWith(
                      color: state.failed ? colors.danger : colors.textMuted,
                    ),
                  ),
                ),
              if (received && c.receivedMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: TeraxSpace.s8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: TeraxSize.dragPreview,
                    ),
                    child: SingleChildScrollView(
                      child: MessagePreview(message: c.receivedMessage!),
                    ),
                  ),
                ),
              if (received)
                Padding(
                  padding: const EdgeInsets.only(top: TeraxSpace.s8),
                  child: LayoutBuilder(
                    builder: (context, bounds) =>
                        _receivedActions(context, bounds.maxWidth),
                  ),
                ),
              if (received &&
                  (c.openingFailure ?? c.automaticOpenNotice) != null)
                Text(
                  (c.openingFailure ?? c.automaticOpenNotice)!,
                  style: TeraxText.caption.copyWith(color: colors.textMuted),
                ),
              if (state.failed || state.stage == TransferViewStage.cancelled)
                Wrap(
                  spacing: TeraxSpace.s8,
                  children: [
                    if (widget.outbound)
                      TextButton.icon(
                        onPressed: c.canSend && c.incoming == null
                            ? (widget.onRetry ?? c.send)
                            : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    TextButton(
                      onPressed: () => showTeraxSettings(context, c),
                      child: const Text('Equipos y ajustes'),
                    ),
                    TextButton(
                      onPressed: widget.onDismiss,
                      child: const Text('Listo'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receivedActions(BuildContext context, double width) {
    final colors = TeraxColors.of(context);
    if (c.receivedMessage != null) {
      return MessageActions(message: c.receivedMessage!);
    }
    final actions = Wrap(
      spacing: TeraxSpace.s8,
      runSpacing: TeraxSpace.s8,
      children: [
        if (c.latestReceived != null) ...[
          TeraxPrimaryButton(
            label: 'Abrir',
            onPressed: () async {
              final file = c.latestReceived!.file;
              c.cancelAutomaticOpen();
              await c.openFile(file);
            },
          ),
          OutlinedButton(
            onPressed: c.server == null ? null : c.openFolder,
            child: const Text('Mostrar en carpeta'),
          ),
        ],
      ],
    );
    if (c.autoOpenDue == null) return actions;
    final countdown = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Se abre en ${math.max(1, c.autoOpenDue!.difference(DateTime.now()).inMilliseconds / 1000).ceil()} s',
          style: TeraxText.caption.copyWith(color: colors.textMuted),
        ),
        TextButton(
          onPressed: c.cancelAutomaticOpen,
          child: const Text('No abrir'),
        ),
      ],
    );
    return width >= TeraxSize.emptyWidth &&
            MediaQuery.textScalerOf(context).scale(1) < 1.4
        ? Row(
            children: [
              Expanded(child: actions),
              const SizedBox(width: TeraxSpace.s12),
              countdown,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              actions,
              Align(alignment: Alignment.centerRight, child: countdown),
            ],
          );
  }
}

class TransferFileVisual extends StatelessWidget {
  const TransferFileVisual({
    super.key,
    required this.name,
    this.file,
    this.preview,
    this.small = false,
    this.message,
  });
  final String name;
  final File? file;
  final Uint8List? preview;
  final bool small;
  final SharedMessage? message;
  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    if (message != null) {
      return MessagePreview(message: message!, compact: small);
    }
    final fallback = small
        ? WindowsTypeBadge(name: name, size: TeraxSize.touch)
        : FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: TeraxSize.paperWidth,
              height: TeraxSize.paperHeight,
              child: WindowsDocument(name: name),
            ),
          );
    Widget child = fallback;
    if (preview != null) {
      child = Image.memory(
        preview!,
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => fallback,
      );
    } else if (file != null &&
        RegExp(
          r'\.(png|jpe?g|webp|gif|bmp)$',
          caseSensitive: false,
        ).hasMatch(name)) {
      child = Image.file(
        file!,
        cacheWidth: small ? 96 : 1200,
        fit: small ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (_, e, s) => fallback,
      );
    }
    return Semantics(
      label: 'Vista previa de $name',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          small ? TeraxRadius.tile : TeraxSpace.s18,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: small
                ? null
                : Border.all(color: c.mint, width: TeraxSize.focusBorder),
            borderRadius: BorderRadius.circular(TeraxSpace.s18),
          ),
          child: Padding(
            padding: EdgeInsets.all(small ? 0 : TeraxSize.focusBorder),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                small ? TeraxRadius.tile : TeraxSpace.s16,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

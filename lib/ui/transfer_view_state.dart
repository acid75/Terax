import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../transfer/transport.dart';

enum TransferViewStage {
  preparingSend,
  preparingReceive,
  transferring,
  verifying,
  sent,
  received,
  cancelled,
  failed,
  integrityError,
}

class TransferViewState {
  const TransferViewState(
    this.stage,
    this.title,
    this.icon, {
    this.message,
    this.progress = 0,
  });
  final TransferViewStage stage;
  final String title;
  final IconData icon;
  final String? message;
  final double progress;
  bool get success =>
      stage == TransferViewStage.sent || stage == TransferViewStage.received;
  bool get failed =>
      stage == TransferViewStage.failed ||
      stage == TransferViewStage.integrityError;
  bool get done => success || failed || stage == TransferViewStage.cancelled;
  static TransferViewState from(AppController c, {required bool outbound}) {
    final progress = outbound
        ? c.progress.clamp(0.0, 1.0)
        : (c.incomingVisual?.total ?? 0) == 0
        ? 0.0
        : ((c.incomingVisual?.bytes ?? 0) / c.incomingVisual!.total).clamp(
            0.0,
            1.0,
          );
    final failure = outbound ? c.error : c.incomingFailure;
    if (outbound && c.state == SendState.failed ||
        !outbound && failure != null) {
      if (failure?.toLowerCase().contains('integridad') == true) {
        return TransferViewState(
          TransferViewStage.integrityError,
          'Error de integridad',
          Icons.gpp_bad_outlined,
          message: 'El archivo llegó dañado y se descartó.',
          progress: progress,
        );
      }
      if (outbound && c.cancelRequested ||
          failure?.toLowerCase().contains('cancelad') == true) {
        return const TransferViewState(
          TransferViewStage.cancelled,
          'Envío cancelado',
          Icons.close,
        );
      }
      return TransferViewState(
        TransferViewStage.failed,
        'No se pudo completar',
        Icons.error_outline,
        message:
            failure ?? 'La transferencia se interrumpió. Vuelve a intentarlo.',
        progress: progress,
      );
    }
    if (outbound && c.state == SendState.complete) {
      return TransferViewState(
        TransferViewStage.sent,
        'Enviado a ${c.outgoingPeerName ?? c.peer?.name ?? 'tu equipo'}',
        Icons.check_circle_outline,
        progress: 1,
      );
    }
    if (!outbound && c.receiveComplete) {
      return const TransferViewState(
        TransferViewStage.received,
        'Recibido y verificado',
        Icons.check_circle_outline,
        progress: 1,
      );
    }
    if (!outbound && c.receiveCancelled) {
      return const TransferViewState(
        TransferViewStage.cancelled,
        'Recepción cancelada',
        Icons.close,
        message: 'La transferencia terminó sin guardar el archivo.',
      );
    }
    if (!outbound && c.incomingVisual?.stage == IncomingStage.verifying) {
      return TransferViewState(
        TransferViewStage.verifying,
        'Verificando…',
        Icons.fact_check_outlined,
        progress: progress,
      );
    }
    if (outbound && c.state == SendState.sending && progress >= .99) {
      return TransferViewState(
        TransferViewStage.verifying,
        'Esperando verificación…',
        Icons.fact_check_outlined,
        progress: progress,
      );
    }
    if (outbound && c.state != SendState.sending) {
      return TransferViewState(
        TransferViewStage.preparingSend,
        'Preparando envío…',
        Icons.more_horiz,
        progress: progress,
      );
    }
    if (!outbound &&
        (c.incomingVisual?.stage == IncomingStage.preparing ||
            c.incomingVisual == null)) {
      return const TransferViewState(
        TransferViewStage.preparingReceive,
        'Preparando recepción…',
        Icons.more_horiz,
      );
    }
    return TransferViewState(
      TransferViewStage.transferring,
      outbound
          ? 'Enviando a ${c.outgoingPeerName ?? c.peer?.name ?? 'tu equipo'}'
          : c.incomingSourceName == null
          ? 'Recibiendo archivo'
          : 'Recibiendo de ${c.incomingSourceName}',
      outbound ? Icons.north_east : Icons.south_west,
      progress: progress,
    );
  }
}

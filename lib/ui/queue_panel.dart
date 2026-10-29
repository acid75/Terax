import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../transfer/transfer_queue.dart';
import '../sharing/shared_message.dart';
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';
import 'settings.dart';

class TransferQueuePage extends StatelessWidget {
  const TransferQueuePage({
    super.key,
    required this.queue,
    required this.controller,
    this.destination,
    this.destinationName,
    this.destinationProvider,
    this.destinationNameProvider,
  });
  final TransferQueue queue;
  final AppController controller;
  final String? destination, destinationName;
  final String? Function()? destinationProvider, destinationNameProvider;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cola de envíos')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([queue, controller]),
        builder: (context, _) {
          final c = TeraxColors.of(context);
          final target = destinationProvider?.call() ?? destination;
          final targetName = destinationNameProvider?.call() ?? destinationName;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(TeraxSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      queue.running
                          ? (queue.paused
                                ? 'Termina este archivo y se pausa'
                                : 'Enviando de uno en uno')
                          : queue.paused
                          ? 'Cola pausada'
                          : 'Prepara tus próximos envíos',
                      style: TeraxText.headline,
                    ),
                    const SizedBox(height: TeraxSpace.s8),
                    if (targetName != null)
                      Text('Destino: $targetName', style: TeraxText.label),
                    if (target != null &&
                        target != controller.peer?.fingerprint)
                      Text(
                        'Selecciona $targetName en Equipos y ajustes para continuar.',
                        style: TeraxText.caption.copyWith(color: c.danger),
                      ),
                    Text(
                      'Mantén Terax abierto en ambos equipos. Un fallo pausa la cola y conserva los siguientes archivos.',
                      style: TeraxText.caption.copyWith(color: c.textMuted),
                    ),
                    Wrap(
                      spacing: TeraxSpace.s8,
                      children: [
                        TextButton.icon(
                          onPressed: queue.running
                              ? (queue.paused ? null : queue.pause)
                              : controller.peerOnline &&
                                    (target == null ||
                                        target ==
                                            controller.peer?.fingerprint) &&
                                    !controller.starting &&
                                    !controller.connecting &&
                                    controller.incoming == null &&
                                    !controller.busy &&
                                    !controller.picking
                              ? queue.start
                              : null,
                          icon: Icon(
                            queue.running ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(
                            queue.running
                                ? (queue.paused
                                      ? 'Pausa programada'
                                      : 'Pausar después de este')
                                : 'Continuar',
                          ),
                        ),
                        TextButton(
                          onPressed: queue.jobs.isEmpty
                              ? null
                              : queue.cancelAll,
                          child: const Text('Cancelar cola'),
                        ),
                        TextButton(
                          onPressed: queue.clearFinished,
                          child: const Text('Quitar finalizados'),
                        ),
                        TextButton(
                          onPressed: () =>
                              showTeraxSettings(context, controller),
                          child: const Text('Equipos y ajustes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: queue.jobs.isEmpty
                    ? const TeraxEmptyState(
                        icon: Icons.playlist_add,
                        title: 'Cola vacía',
                        message:
                            'Elige varios archivos o agrégalos desde Compartir.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(TeraxSpace.s16),
                        itemCount: queue.jobs.length,
                        itemBuilder: (context, i) {
                          final job = queue.jobs[i];
                          final (label, icon) = switch (job.state) {
                            TransferJobState.pending => (
                              'Pendiente',
                              Icons.schedule,
                            ),
                            TransferJobState.sending => (
                              'Enviando',
                              Icons.north_east,
                            ),
                            TransferJobState.sent => (
                              'Enviado y verificado',
                              Icons.check_circle_outline,
                            ),
                            TransferJobState.failed => (
                              'No se pudo enviar',
                              Icons.error_outline,
                            ),
                            TransferJobState.cancelled => (
                              'Cancelado',
                              Icons.close,
                            ),
                          };
                          return ListTile(
                            leading: Icon(
                              icon,
                              color: job.state == TransferJobState.failed
                                  ? c.danger
                                  : c.mint,
                            ),
                            title: Text(
                              SharedMessage.displayName(job.item.name),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$label · ${formatBytes(job.item.size)}${job.error == null ? '' : '\n${job.error}'}',
                            ),
                            trailing: job.state == TransferJobState.failed
                                ? IconButton(
                                    tooltip: 'Reintentar',
                                    onPressed: queue.running
                                        ? null
                                        : () => queue.retry(job.id),
                                    icon: const Icon(Icons.refresh),
                                  )
                                : job.state != TransferJobState.sending
                                ? IconButton(
                                    tooltip: 'Quitar de la cola',
                                    onPressed: () => queue.remove(job.id),
                                    icon: const Icon(Icons.close),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

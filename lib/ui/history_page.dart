import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../sharing/shared_message.dart';
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';
import 'message_composer.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});
  final AppController controller;
  Future<void> open(BuildContext context, HistoryEntry entry) async {
    if (!await entry.file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo ya no está en este dispositivo.'),
          ),
        );
      }
      return;
    }
    final msg = await SharedMessage.read(entry.file, name: entry.name);
    if (!context.mounted) return;
    if (msg != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(msg.label),
          content: SizedBox(
            width: TeraxSize.emptyWidth,
            height: TeraxSize.camera,
            child: MessagePreview(message: msg),
          ),
          actions: [
            MessageActions(message: msg),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } else {
      controller.clearMessage();
      await controller.openFile(entry.file);
      if (context.mounted && controller.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(controller.error!)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Historial'),
      actions: [
        IconButton(
          tooltip: 'Borrar historial',
          onPressed: () async {
            final yes = await showTeraxConfirmation(
              context,
              title: '¿Borrar historial?',
              explanation: 'Se quitará la lista de transferencias.',
              preservation: 'Los archivos recibidos no se borran.',
              confirmLabel: 'Borrar historial',
            );
            if (yes == true) {
              final cleared = await controller.clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      cleared
                          ? 'Historial borrado'
                          : 'No se pudo borrar el historial. Intenta de nuevo.',
                    ),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = TeraxColors.of(context);
          return controller.history.isEmpty
              ? const TeraxEmptyState(
                  icon: Icons.history,
                  title: 'Sin transferencias todavía',
                  message:
                      'Los envíos completados y archivos recibidos quedan guardados aquí.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(TeraxSpace.s16),
                  itemCount: controller.history.length,
                  separatorBuilder: (_, i) =>
                      const SizedBox(height: TeraxSpace.s8),
                  itemBuilder: (context, i) {
                    final entry = controller.history[i];
                    final date = entry.time;
                    return ListTile(
                      tileColor: c.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(TeraxRadius.lg),
                      ),
                      leading: Icon(
                        entry.incoming ? Icons.south_west : Icons.north_east,
                        color: c.mint,
                      ),
                      title: Text(
                        SharedMessage.displayName(entry.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.incoming ? 'Recibido y verificado' : 'Enviado'} · ${formatBytes(entry.size)}\n${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                        style: TeraxText.caption,
                      ),
                      isThreeLine: true,
                      onTap: () => open(context, entry),
                    );
                  },
                );
        },
      ),
    ),
  );
}

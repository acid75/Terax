import 'package:flutter/material.dart';
import '../theme/terax_theme.dart';

enum SharingCommand { history, queue, sounds }

class SharingActions extends StatelessWidget {
  const SharingActions({
    super.key,
    required this.onFiles,
    required this.onMessage,
    required this.onCommand,
    required this.sounds,
    required this.pending,
  });
  final VoidCallback? onFiles, onMessage;
  final ValueChanged<SharingCommand> onCommand;
  final bool sounds;
  final int pending;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: TeraxSpace.s4,
    runSpacing: TeraxSpace.s4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton.icon(
        onPressed: onFiles,
        icon: const Icon(Icons.attach_file, size: TeraxSize.iconSm),
        label: const Text('Archivos'),
      ),
      TextButton.icon(
        onPressed: onMessage,
        icon: const Icon(Icons.notes, size: TeraxSize.iconSm),
        label: const Text('Texto y enlaces'),
      ),
      PopupMenuButton<SharingCommand>(
        tooltip: 'Más opciones',
        onSelected: onCommand,
        icon: Badge(
          isLabelVisible: pending > 0,
          label: Text('$pending'),
          child: const Icon(Icons.more_horiz),
        ),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: SharingCommand.history,
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('Historial'),
            ),
          ),
          PopupMenuItem(
            value: SharingCommand.queue,
            child: ListTile(
              leading: const Icon(Icons.playlist_play),
              title: Text('Cola de envíos ($pending)'),
            ),
          ),
          PopupMenuItem(
            value: SharingCommand.sounds,
            child: ListTile(
              leading: Icon(
                sounds ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              ),
              title: Text(sounds ? 'Silenciar sonidos' : 'Activar sonidos'),
            ),
          ),
        ],
      ),
    ],
  );
}

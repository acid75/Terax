import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_controller.dart';
import '../transfer/protocol.dart';
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';
import 'pairing.dart';

class WindowsSettings extends StatefulWidget {
  const WindowsSettings({super.key, required this.controller});
  final AppController controller;
  @override
  State<WindowsSettings> createState() => _WindowsSettingsState();
}

class _WindowsSettingsState extends State<WindowsSettings> {
  bool working = false;
  AppController get c => widget.controller;
  bool get disabled =>
      working ||
      c.proximityWorking ||
      c.busy ||
      c.starting ||
      c.connecting ||
      c.resettingLinks ||
      c.incoming != null ||
      c.picking;
  Future<void> run(Future<void> Function() action) async {
    if (disabled) return;
    setState(() => working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> reset() async {
    if (disabled) return;
    final yes = await showTeraxConfirmation(
      context,
      title: '¿Restablecer vínculos?',
      explanation:
          'Tus equipos dejarán de estar autorizados y tendrás que vincularlos otra vez con el código QR.',
      preservation: 'Los archivos recibidos no se borran.',
      confirmLabel: 'Restablecer',
    );
    if (yes && mounted) await run(c.resetLinks);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final colors = TeraxColors.of(context);
      final peers = <String, PairingInfo>{
        for (final p in c.knownPeers) p.fingerprint: p,
        if (c.peer != null) c.peer!.fingerprint: c.peer!,
      }.values.toList();
      final own = c.ownPairing;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TeraxSpace.s24,
                TeraxSpace.s12,
                TeraxSpace.s12,
                TeraxSpace.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Equipos y ajustes',
                      style: TeraxText.headline.copyWith(color: colors.text),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar ajustes',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  TeraxSpace.s24,
                  0,
                  TeraxSpace.s24,
                  TeraxSpace.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heading('Tus equipos'),
                    for (final peer in peers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: TeraxSpace.s8),
                        child: Material(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(TeraxRadius.lg),
                          child: ListTile(
                            leading: Icon(
                              Icons.phone_android_outlined,
                              color: colors.mint,
                            ),
                            title: Text(
                              peer.name,
                              style: TeraxText.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  c.peerOnline &&
                                          peer.fingerprint ==
                                              c.peer?.fingerprint
                                      ? Icons.check
                                      : Icons.link_off,
                                  size: TeraxSize.iconSm,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(width: TeraxSpace.s4),
                                Expanded(
                                  child: Text(
                                    c.peerOnline &&
                                            peer.fingerprint ==
                                                c.peer?.fingerprint
                                        ? (c.nearbyFingerprint ==
                                                  peer.fingerprint
                                              ? 'Conectado · Cerca'
                                              : 'Conectado')
                                        : 'Vinculada · sin respuesta',
                                    style: TeraxText.caption.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (peers.isEmpty)
                      const Text(
                        'Vincula tus equipos una vez para que se reconozcan al abrir Terax.',
                        style: TeraxText.caption,
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: disabled
                            ? null
                            : () => showConnectDialog(context, c),
                        icon: const Icon(Icons.add),
                        label: const Text('Vincular otro equipo'),
                      ),
                    ),
                    ExpansionTile(
                      key: ValueKey(peers.isEmpty),
                      initiallyExpanded: peers.isEmpty,
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Código de este equipo',
                        style: TeraxText.label,
                      ),
                      children: [
                        if (own != null) ...[
                          const Text(
                            'Abre Terax en el teléfono y escanea este código. Solo se hace una vez.',
                            style: TeraxText.caption,
                          ),
                          const SizedBox(height: TeraxSpace.s12),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: TeraxSize.camera,
                              ),
                              child: Semantics(
                                label:
                                    'Código QR para conectar con este equipo',
                                image: true,
                                child: ColoredBox(
                                  color: TeraxColors.qrPaper,
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      TeraxSpace.s12,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: QrImageView(
                                        data: own.encode(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: TeraxSpace.s12),
                          OutlinedButton.icon(
                            onPressed: disabled
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: own.encode()),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Código copiado. Compártelo solo con tu otro equipo.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copiar código'),
                          ),
                        ] else ...[
                          Text(
                            c.starting
                                ? 'Preparando conexión segura…'
                                : 'Conecta este equipo a Wi-Fi para mostrar su código.',
                            style: TeraxText.caption,
                          ),
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () => run(
                                    c.server == null
                                        ? c.initialize
                                        : c.refreshNetwork,
                                  ),
                            child: const Text('Volver a intentar'),
                          ),
                        ],
                        const SizedBox(height: TeraxSpace.s16),
                      ],
                    ),
                    const SizedBox(height: TeraxSpace.s16),
                    _heading('Recepción'),
                    TeraxSwitchRow(
                      title: 'Permitir recepción',
                      subtitle: 'Desde tus equipos vinculados',
                      value: c.server?.accepting ?? false,
                      onChanged: disabled || c.server == null
                          ? null
                          : c.setAccepting,
                    ),
                    TeraxSwitchRow(
                      title: 'Abrir fotos y documentos al recibir',
                      subtitle: 'Después de verificar el archivo',
                      value: c.autoOpenImages,
                      onChanged: disabled ? null : c.setAutoOpen,
                    ),
                    TeraxSwitchRow(
                      title: 'Sonidos de transferencia',
                      subtitle:
                          'Salida y llegada como dos partes del mismo sonido.',
                      value: c.sounds.enabled,
                      onChanged: c.setTransferSounds,
                    ),
                    const SizedBox(height: TeraxSpace.s16),
                    _heading('Onda de transferencia'),
                    Text(
                      TeraxMotion.reduced(context)
                          ? 'Movimiento reducido activado: la onda se omite.'
                          : 'Se repliega al enviar y se expande al recibir, dentro de Terax.',
                      style: TeraxText.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: TeraxSpace.s16),
                    _heading('Cercanía'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.bluetooth, color: colors.textMuted),
                        const SizedBox(width: TeraxSpace.s12),
                        Expanded(
                          child: Text(
                            c.proximityStatus,
                            style: TeraxText.caption,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Bluetooth solo estima cercanía. Puedes seguir enviando por Wi-Fi.',
                      style: TeraxText.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: disabled || c.server == null
                            ? null
                            : () => run(() => c.enableProximity()),
                        child: Text(
                          c.proximityWorking
                              ? 'Comprobando…'
                              : 'Reintentar Bluetooth',
                        ),
                      ),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Detalles de red',
                        style: TeraxText.label,
                      ),
                      children: [
                        if (c.addresses.length > 1)
                          DropdownButtonFormField<String>(
                            key: ValueKey(c.address),
                            initialValue: c.addresses.contains(c.address)
                                ? c.address
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Dirección de red',
                            ),
                            style: TeraxText.monoSm.copyWith(
                              color: colors.text,
                            ),
                            items: c.addresses
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a, style: TeraxText.monoSm),
                                  ),
                                )
                                .toList(),
                            onChanged: disabled
                                ? null
                                : (a) {
                                    if (a != null) c.chooseAddress(a);
                                  },
                          )
                        else
                          SelectableText(
                            c.address ?? 'Sin conexión de red',
                            style: TeraxText.monoSm.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        TextButton.icon(
                          onPressed: disabled
                              ? null
                              : () => run(
                                  c.server == null
                                      ? c.initialize
                                      : c.refreshNetwork,
                                ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar red'),
                        ),
                      ],
                    ),
                    const SizedBox(height: TeraxSpace.s24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: colors.danger,
                        ),
                        onPressed: disabled ? null : reset,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Restablecer vínculos'),
                      ),
                    ),
                    const SizedBox(height: TeraxSpace.s16),
                    Text(
                      'Al cerrar la ventana, Terax sigue en la bandeja. Usa Salir desde su icono para detenerlo.',
                      style: TeraxText.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: TeraxSpace.s8),
    child: Text(
      title,
      style: TeraxText.label.copyWith(color: TeraxColors.of(context).textMuted),
    ),
  );
}

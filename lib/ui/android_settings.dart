import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_controller.dart';
import '../sharing/audio_access.dart';
import '../theme/terax_theme.dart';
import '../transfer/protocol.dart';
import 'components/terax_components.dart';
import 'ui_issue.dart';
import 'pairing.dart';

class AndroidSettings extends StatefulWidget {
  const AndroidSettings({super.key, required this.controller});
  final AppController controller;
  @override
  State<AndroidSettings> createState() => _AndroidSettingsState();
}

class _AndroidSettingsState extends State<AndroidSettings> {
  bool working = false, slowBluetooth = false;
  Timer? timeout;
  AppController get c => widget.controller;
  bool get disabled =>
      working ||
      c.busy ||
      c.starting ||
      c.connecting ||
      c.resettingLinks ||
      c.incoming != null;
  @override
  void initState() {
    super.initState();
    c.addListener(_updated);
    _watchBluetooth();
  }

  void _updated() {
    _watchBluetooth();
    if (mounted) setState(() {});
  }

  UiIssue? get nearbyIssue {
    if (c.proximityWorking) return null;
    final status = c.proximityStatus.toLowerCase();
    if (status.contains('no admite')) {
      return UiIssue.describe(UiIssueKind.bluetoothUnavailable);
    }
    if (status.contains('enciende bluetooth') || status.contains('apagado')) {
      return UiIssue.describe(UiIssueKind.bluetoothOff);
    }
    if (status.startsWith('activa el permiso') ||
        status.contains('sin permiso')) {
      return UiIssue.describe(UiIssueKind.nearbyPermission);
    }
    return null;
  }

  void _watchBluetooth() {
    if (c.proximityWorking) {
      timeout ??= Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => slowBluetooth = true);
      });
    } else {
      timeout?.cancel();
      timeout = null;
      slowBluetooth = false;
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    c.removeListener(_updated);
    super.dispose();
  }

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
    final yes = await showTeraxConfirmation(
      context,
      title: '¿Restablecer vínculos?',
      explanation:
          'Tus equipos dejarán de estar autorizados y tendrás que vincularlos otra vez con el código QR.',
      preservation: 'Los archivos recibidos no se borran.',
      confirmLabel: 'Restablecer',
    );
    if (yes == true && mounted) await run(c.resetLinks);
  }

  @override
  Widget build(BuildContext context) {
    final colors = TeraxColors.of(context);
    final peers = <String, PairingInfo>{
      for (final peer in c.knownPeers) peer.fingerprint: peer,
      if (c.peer != null) c.peer!.fingerprint: c.peer!,
    }.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipos y ajustes'),
        titleTextStyle: TeraxText.headline.copyWith(color: colors.text),
        backgroundColor: colors.bg,
        surfaceTintColor: TeraxColors.clear,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(TeraxSpace.s16),
          children: [
            _section('Tus equipos'),
            _card(
              Column(
                children: [
                  for (var i = 0; i < peers.length; i++) ...[
                    if (i > 0) Divider(color: colors.outline),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colors.iconContainer,
                        foregroundColor: colors.mint,
                        child: const Icon(Icons.desktop_windows_outlined),
                      ),
                      title: Text(
                        peers[i].name,
                        style: TeraxText.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: TeraxSpace.s8),
                        child: Wrap(
                          spacing: TeraxSpace.s6,
                          runSpacing: TeraxSpace.s4,
                          children: [
                            _pill(
                              c.peerOnline &&
                                      peers[i].fingerprint ==
                                          c.peer?.fingerprint
                                  ? 'Conectado'
                                  : 'Vinculada · sin respuesta',
                              c.peerOnline &&
                                      peers[i].fingerprint ==
                                          c.peer?.fingerprint
                                  ? Icons.check
                                  : Icons.link_off,
                            ),
                            if (c.peerOnline &&
                                peers[i].fingerprint == c.peer?.fingerprint &&
                                c.nearbyFingerprint == peers[i].fingerprint)
                              _pill('Cerca', Icons.wifi_tethering),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(peers[i].name),
                          content: SelectableText(
                            peers[i].host,
                            style: TeraxText.monoSm,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (peers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: TeraxSpace.s12),
                      child: Text(
                        'Vincula tus equipos una vez para que se reconozcan al abrir Terax.',
                        style: TeraxText.caption,
                      ),
                    ),
                ],
              ),
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
            const SizedBox(height: TeraxSpace.s20),
            _section('Cercanía'),
            _card(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.bluetooth,
                    color: colors.textMuted,
                    size: TeraxSize.iconLg,
                  ),
                  const SizedBox(width: TeraxSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slowBluetooth
                              ? 'Bluetooth tarda en responder'
                              : nearbyIssue?.title ?? c.proximityStatus,
                          style: TeraxText.label,
                        ),
                        const SizedBox(height: TeraxSpace.s4),
                        Text(
                          nearbyIssue?.body ??
                              'Bluetooth solo estima cercanía. Puedes seguir enviando por Wi-Fi.',
                          style: TeraxText.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        if (slowBluetooth ||
                            (!c.proximityWorking &&
                                c.proximityStatus.toLowerCase().contains(
                                  'permiso',
                                )))
                          TextButton(
                            onPressed: c.openProximitySettings,
                            child: const Text('Abrir permisos'),
                          )
                        else if (!c.proximityStatus.contains('no admite'))
                          TextButton(
                            onPressed:
                                disabled ||
                                    c.proximityWorking ||
                                    c.server == null
                                ? null
                                : () => run(() => c.enableProximity()),
                            child: Text(
                              c.proximityWorking
                                  ? 'Comprobando…'
                                  : (c.proximityStatus.toLowerCase().contains(
                                          'apagado',
                                        ) ||
                                        c.proximityStatus
                                            .toLowerCase()
                                            .contains('enciende bluetooth'))
                                  ? 'Activar Bluetooth'
                                  : 'Reintentar cercanía',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TeraxSpace.s20),
            _card(
              Column(
                children: [
                  TeraxSwitchRow(
                    title: 'Permitir recepción',
                    subtitle: 'Desde tus equipos vinculados',
                    value: c.server?.accepting ?? false,
                    onChanged: disabled || c.server == null
                        ? null
                        : c.setAccepting,
                  ),
                  const Divider(),
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
                  TextButton.icon(
                    onPressed: disabled
                        ? null
                        : () async {
                            final granted = await AudioAccess.request();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  granted
                                      ? 'Acceso a archivos de audio permitido.'
                                      : 'Acceso no autorizado. Puedes seguir usando Archivos y los sonidos de Terax.',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.audio_file_outlined),
                    label: const Text('Permiso para archivos de audio'),
                  ),
                  const Divider(),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Detalles de red', style: TeraxText.body),
                    subtitle: Text(
                      c.address ?? 'Sin conexión',
                      style: TeraxText.monoSm.copyWith(color: colors.textMuted),
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
                            labelText: 'Interfaz de red',
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
                      if (c.ownPairing != null) ...[
                        const Text(
                          'Código de este equipo',
                          style: TeraxText.label,
                        ),
                        const SizedBox(height: TeraxSpace.s12),
                        Container(
                          width: TeraxSize.camera,
                          padding: const EdgeInsets.all(TeraxSpace.s12),
                          color: TeraxColors.qrPaper,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Semantics(
                              label: 'Código QR para conectar con este equipo',
                              image: true,
                              child: QrImageView(
                                data: c.ownPairing!.encode(),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: disabled
                              ? null
                              : () => Clipboard.setData(
                                  ClipboardData(text: c.ownPairing!.encode()),
                                ),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar código'),
                        ),
                      ],
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Permisos de Terax en Android',
                      style: TeraxText.body,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: c.openProximitySettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: TeraxSpace.s20),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                onPressed: disabled || c.proximityWorking ? null : reset,
                icon: const Icon(Icons.link_off),
                label: const Text('Restablecer vínculos'),
              ),
            ),
            if (c.history.isNotEmpty)
              ExpansionTile(
                title: const Text(
                  'Actividad de esta sesión',
                  style: TeraxText.label,
                ),
                subtitle: const Text(
                  'Se borra al salir',
                  style: TeraxText.caption,
                ),
                children: [
                  for (final entry in c.history.take(10))
                    ListTile(
                      leading: Icon(
                        entry.incoming ? Icons.south_west : Icons.north_east,
                      ),
                      title: Text(
                        entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        formatBytes(entry.size),
                        style: TeraxText.monoSm,
                      ),
                      onTap: () => c.openFile(entry.file),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: TeraxSpace.s12),
    child: Text(
      text,
      style: TeraxText.label.copyWith(color: TeraxColors.of(context).textMuted),
    ),
  );
  Widget _card(Widget child) => Material(
    color: TeraxColors.of(context).surface,
    borderRadius: BorderRadius.circular(TeraxRadius.sheet),
    child: Padding(padding: const EdgeInsets.all(TeraxSpace.s16), child: child),
  );
  Widget _pill(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: TeraxSpace.s8,
      vertical: TeraxSpace.s4,
    ),
    decoration: BoxDecoration(
      color: TeraxColors.of(context).iconContainer,
      borderRadius: BorderRadius.circular(TeraxRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: TeraxSize.iconSm, color: TeraxColors.of(context).mint),
        const SizedBox(width: TeraxSpace.s4),
        Flexible(
          child: Text(
            text,
            style: TeraxText.caption.copyWith(
              color: TeraxColors.of(context).mint,
            ),
          ),
        ),
      ],
    ),
  );
}

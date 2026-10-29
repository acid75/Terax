import 'dart:io';
import '../theme/terax_theme.dart';
import 'components/terax_components.dart';
import 'pairing_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_controller.dart';

Future<void> showConnectDialog(BuildContext context, AppController controller) {
  if (TeraxPlatform.of(context) == TeraxPlatform.android) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ConnectDialog(controller, fullPage: true),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => _ConnectDialog(controller),
  );
}

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog(this.controller, {this.fullPage = false});
  final bool fullPage;
  final AppController controller;
  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final input = TextEditingController();
  String? error;
  bool busy = false, showCode = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> connect(String code) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final success = await widget.controller.connect(code);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        busy = false;
        error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.fullPage
      ? _android(context)
      : AlertDialog(
          title: const Text('Autorizar tu equipo una vez'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Escanea el QR o pega el código de tu otro equipo una sola vez. El vínculo se guarda y después se reconectan solos. Ambos deben estar en la misma red.',
                  ),
                  const SizedBox(height: 20),
                  if (Platform.isAndroid) ...[
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final code = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const _Scanner(),
                                ),
                              );
                              if (code != null && mounted) await connect(code);
                            },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Escanear QR'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: input,
                    minLines: 2,
                    maxLines: 4,
                    enabled: !busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Código de conexión',
                      hintText: 'terax:1:…',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: busy ? null : () => connect(input.text),
              child: const Text('Conectar'),
            ),
          ],
        );
  Widget _android(BuildContext context) {
    final colors = TeraxColors.of(context);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.bg,
          surfaceTintColor: TeraxColors.clear,
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, size) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                TeraxSpace.s24,
                0,
                TeraxSpace.s24,
                TeraxSpace.s24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (size.maxHeight - TeraxSpace.s24).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: TeraxBrand(),
                      ),
                      const SizedBox(height: TeraxSpace.s32),
                      Text(
                        'Vincula tu PC',
                        style: TeraxText.onboardingTitle.copyWith(
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: TeraxSpace.s12),
                      Text(
                        'Abre Terax en tu computadora y escanea el código que aparece. Solo se hace una vez.',
                        style: TeraxText.bodyLg.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: TeraxSpace.s28),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: TeraxSize.camera,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: PairingCamera(onCode: connect),
                          ),
                        ),
                      ),
                      const SizedBox(height: TeraxSpace.s24),
                      _step(
                        '1',
                        'Conecta el teléfono y la PC a la misma red Wi-Fi.',
                      ),
                      const SizedBox(height: TeraxSpace.s12),
                      _step(
                        '2',
                        'Después se reconectan solos cada vez que abras Terax.',
                      ),
                      const SizedBox(height: TeraxSpace.s24),
                      const Spacer(),
                      if (showCode) ...[
                        TextField(
                          controller: input,
                          minLines: 2,
                          maxLines: 4,
                          enabled: !busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Código de conexión',
                            hintText: 'terax:1:…',
                          ),
                        ),
                        const SizedBox(height: TeraxSpace.s12),
                        TeraxPrimaryButton(
                          label: 'Conectar',
                          icon: Icons.link,
                          onPressed: busy ? null : () => connect(input.text),
                          busy: busy,
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  setState(() => showCode = true);
                                  try {
                                    final value = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    if (mounted && input.text.isEmpty) {
                                      setState(
                                        () => input.text = value?.text ?? '',
                                      );
                                    }
                                  } catch (_) {
                                    /* Manual entry remains available. */
                                  }
                                },
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Pegar código de conexión'),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: TeraxSpace.s12),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: colors.danger),
                              const SizedBox(width: TeraxSpace.s8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TeraxText.caption.copyWith(
                                    color: colors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(String number, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: TeraxSpace.s12,
        backgroundColor: TeraxColors.of(context).surface,
        foregroundColor: TeraxColors.of(context).mint,
        child: Text(number, style: TeraxText.label),
      ),
      const SizedBox(width: TeraxSpace.s12),
      Expanded(child: Text(text, style: TeraxText.caption)),
    ],
  );
}

class _Scanner extends StatefulWidget {
  const _Scanner();
  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  final camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool captured = false;
  String? qrError;
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear el QR de Terax')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: camera,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No se pudo usar la cámara. Permite el acceso en Ajustes o vuelve y pega el código de conexión.',
                ),
              ),
            ),
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (!captured && code != null && code.startsWith('terax:1:')) {
                  captured = true;
                  Navigator.pop(context, code);
                  return;
                } else if (!captured && code != null) {
                  setState(
                    () => qrError =
                        'Este QR no es de Terax. Escanea el código que aparece en tu PC.',
                  );
                }
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TeraxSpace.s24),
          child: Text(
            qrError ?? 'Apunta al QR que aparece en el otro equipo.',
            style: TeraxText.caption.copyWith(
              color: qrError == null
                  ? TeraxColors.of(context).textMuted
                  : TeraxColors.of(context).danger,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Pegar código de conexión'),
        ),
      ],
    ),
  );
}

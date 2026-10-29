import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:photo_manager/photo_manager.dart';
import '../theme/terax_theme.dart';

/// Camera presentation; authorization and pairing remain in AppController.connect.
class PairingCamera extends StatefulWidget {
  const PairingCamera({super.key, required this.onCode});
  final Future<void> Function(String) onCode;
  @override
  State<PairingCamera> createState() => _PairingCameraState();
}

class _PairingCameraState extends State<PairingCamera> {
  final camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool captured = false;
  String? invalid;
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  Future<void> detected(BarcodeCapture capture) async {
    if (captured) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null) continue;
      if (!code.startsWith('terax:1:')) {
        setState(() => invalid = 'Este QR no es de Terax.');
        return;
      }
      captured = true;
      await camera.stop();
      if (!mounted) return;
      await widget.onCode(code);
      if (!mounted) return;
      captured = false;
      try {
        await camera.start();
      } catch (_) {
        if (mounted) {
          setState(
            () => invalid =
                'No se pudo usar la cámara. Pega el código de conexión.',
          );
        }
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TeraxColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TeraxRadius.sheet),
      child: ColoredBox(
        color: c.surface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (Platform.isAndroid)
              MobileScanner(
                controller: camera,
                onDetect: detected,
                errorBuilder: (context, error) => SingleChildScrollView(
                  padding: const EdgeInsets.all(TeraxSpace.s32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.no_photography_outlined, color: c.danger),
                      const SizedBox(height: TeraxSpace.s8),
                      Text(
                        'La cámara no está disponible. Permite el acceso o pega el código de conexión.',
                        textAlign: TextAlign.center,
                        style: TeraxText.caption,
                      ),
                      TextButton(
                        onPressed: PhotoManager.openSetting,
                        child: const Text('Abrir permisos'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(TeraxSpace.s40),
                  child: Text(
                    'Apunta la cámara al código QR de tu PC',
                    textAlign: TextAlign.center,
                    style: TeraxText.caption.copyWith(color: c.textMuted),
                  ),
                ),
              ),
            IgnorePointer(child: CustomPaint(painter: _Corners(c.mint))),
            if (invalid != null)
              Positioned(
                left: TeraxSpace.s24,
                right: TeraxSpace.s24,
                bottom: TeraxSpace.s24,
                child: ColoredBox(
                  color: c.bg,
                  child: Text(
                    invalid!,
                    textAlign: TextAlign.center,
                    style: TeraxText.caption.copyWith(color: c.danger),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Corners extends CustomPainter {
  _Corners(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = TeraxSpace.s4;
    for (final x in [1.0, -1.0]) {
      for (final y in [1.0, -1.0]) {
        canvas.save();
        canvas.translate(x > 0 ? 0 : size.width, y > 0 ? 0 : size.height);
        canvas.scale(x, y);
        canvas.drawPath(
          Path()
            ..moveTo(TeraxSpace.s20 + TeraxSize.touch, TeraxSpace.s20)
            ..lineTo(TeraxSpace.s20 + TeraxSpace.s12, TeraxSpace.s20)
            ..quadraticBezierTo(
              TeraxSpace.s20,
              TeraxSpace.s20,
              TeraxSpace.s20,
              TeraxSpace.s20 + TeraxSpace.s12,
            )
            ..lineTo(TeraxSpace.s20, TeraxSpace.s20 + TeraxSize.touch),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Corners oldDelegate) =>
      oldDelegate.color != color;
}

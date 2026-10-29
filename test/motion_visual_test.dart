import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/main.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/ui/transfer_scene.dart';

void main() {
  testWidgets(
    'Windows waits for presentation then animates even a completed receipt',
    (tester) async {
      final c = AppController()
        ..starting = false
        ..incomingVisual = const IncomingProgress(
          'Prueba.pdf',
          100,
          100,
          id: 'native-ready',
        )
        ..receiveComplete = true
        ..incomingAnimationReady = false;
      addTearDown(c.dispose);
      Widget scene() => MaterialApp(
        theme: teraxTheme(),
        home: Scaffold(
          body: TransferScene(controller: c, outbound: false, onDismiss: () {}),
        ),
      );
      await tester.pumpWidget(scene());
      final finder = find.byKey(const ValueKey('transfer-object-opacity'));
      final before = tester.getTopLeft(finder);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getTopLeft(finder), before);
      c.incomingAnimationReady = true;
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(milliseconds: 200));
      final entering = tester.getTopLeft(finder);
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.getTopLeft(finder).dy, lessThan(entering.dy - 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  if (Platform.environment['TERAX_CAPTURE'] != '1') return;
  for (final width in [390.0, 1200.0]) {
    testWidgets('capture receiver $width', (tester) async {
      await tester.runAsync(() async {
        final font = FontLoader('Segoe UI');
        font.addFont(
          File(
            'C:/Windows/Fonts/segoeui.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
        await font.load();
      });
      tester.view.physicalSize = Size(width, width < 500 ? 844 : 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController()
        ..starting = false
        ..incomingVisual = const IncomingProgress(
          'Presentación.pdf',
          256,
          1024,
          id: 'capture',
        );
      addTearDown(c.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: teraxTheme(),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: TransferScene(
                controller: c,
                outbound: false,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      // Decode local effect layers before capturing the deterministic timeline.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      var previous = 0;
      for (final ms in List.generate(37, (i) => i * 50)) {
        await tester.pump(Duration(milliseconds: ms - previous));
        previous = ms;
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('tmp/motion').create(recursive: true);
          await File(
            'tmp/motion/receiver-${width.toInt()}-$ms.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}

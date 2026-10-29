import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:terax/transfer/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/ui/edge_portal.dart';
import 'package:terax/ui/edge_motion.dart';
import 'package:terax/ui/transfer_scene.dart';

void main() {
  testWidgets('idle portal has no continuous animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EdgePortal(top: true, active: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
  testWidgets('outbound object leaves only after acknowledged ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = AppController()
      ..starting = false
      ..selectedName = 'Informe.pdf'
      ..selectedSize = 1024
      ..state = SendState.preparing;
    addTearDown(c.dispose);
    Widget scene() => MaterialApp(
      home: Scaffold(
        body: TransferScene(controller: c, outbound: true, onDismiss: () {}),
      ),
    );
    await tester.pumpWidget(scene());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('transfer-flight-overlay')), findsNothing);
    c.outgoingId = 'acknowledged';
    await tester.pumpWidget(scene());
    await tester.pump();
    expect(
      find.byKey(const ValueKey('transfer-flight-overlay')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 340));
    await tester.pump();
    expect(find.byKey(const ValueKey('transfer-flight-overlay')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion stops the active portal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: EdgePortal(top: false, active: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
  testWidgets(
    'receiver shows offered preview before a verified file exists at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController()
        ..starting = false
        ..incomingVisual = const IncomingProgress(
          'Foto.png',
          20,
          100,
          id: 'incoming-offer',
        )
        ..incomingPreview = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
        );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferScene(
              controller: c,
              outbound: false,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.latestReceived, isNull);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
        findsOneWidget,
      );
      expect(find.text('Recibiendo archivo'), findsOneWidget);
      expect(find.text('Abrir'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'completed reception replaces offered thumbnail with verified image',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
      );
      final file = await tester.runAsync(() async {
        final folder = await Directory.systemTemp.createTemp('terax-scene-');
        addTearDown(() => folder.delete(recursive: true));
        return File('${folder.path}/verified.png').writeAsBytes(bytes);
      });
      final c = AppController()
        ..starting = false
        ..incomingVisual = const IncomingProgress(
          'Foto.png',
          100,
          100,
          id: 'verified',
        )
        ..incomingPreview = bytes
        ..receiveComplete = true
        ..latestReceived = ReceivedFile(
          file!,
          'Foto.png',
          bytes.length,
          id: 'verified',
        );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferScene(
              controller: c,
              outbound: false,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      final image = tester.widget<Image>(
        find.byWidgetPredicate((w) => w is Image && w.image is ResizeImage),
      );
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).imageProvider, isA<FileImage>());
      expect((image.image as ResizeImage).width, 1200);
    },
  );
  testWidgets(
    'fast verified receipt finishes its finite landing without hiding status',
    (tester) async {
      final c = AppController()
        ..starting = false
        ..incomingVisual = const IncomingProgress('Tiny.txt', 1, 1, id: 'tiny')
        ..receiveComplete = true;
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferScene(
              controller: c,
              outbound: false,
              onDismiss: () {},
            ),
          ),
        ),
      );
      final timeline = tester
          .widget<EdgeMotion>(find.byType(EdgeMotion))
          .timeline;
      expect(timeline.value, 0);
      expect(find.text('Recibido y verificado'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(timeline.value, lessThan(1));
      await tester.pump(const Duration(milliseconds: 350));
      expect(timeline.value, 1);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    },
  );
}

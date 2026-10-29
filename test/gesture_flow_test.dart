import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/ui/swipe_card.dart';
import 'package:terax/ui/transfer_scene.dart';
import 'package:terax/main.dart';
import 'package:terax/theme/terax_theme.dart';

// The file and library are real. Only the remote receiver is gated, allowing
// assertions during the transfer rather than racing a localhost connection.
class _Receiver extends TransferClient {
  final completed = Completer<void>();
  @override
  Future<void> send(
    File file,
    PairingInfo peer, {
    ProgressCallback? onProgress,
    void Function(TransferOffer)? onReady,
    String? name,
    String? preview,
  }) async {
    final bytes = await file.readAsBytes();
    onReady?.call(
      TransferOffer(
        id: 'a' * 32,
        name: name!,
        size: bytes.length,
        preview: preview,
      ),
    );
    onProgress?.call(.45);
    await completed.future;
    onProgress?.call(1);
  }
}

class _Fixture {
  _Fixture(this.root, this.library, this.controller, this.receiver);
  final Directory root;
  final LibraryService library;
  final AppController controller;
  final _Receiver receiver;
  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp('terax-gesture-');
    await File(
      '${root.path}/reporte.txt',
    ).writeAsString('Reporte de campo real.');
    final library = LibraryService(
      android: false,
      roots: {
        LibraryKind.document: [root],
      },
    );
    await library.load(LibraryKind.document);
    final receiver = _Receiver();
    final controller = AppController(client: receiver)
      ..peer = PairingInfo(
        host: '127.0.0.1',
        port: 4040,
        token: 'b' * 64,
        fingerprint: 'c' * 64,
        name: 'Mi PC',
      )
      ..peerOnline = true
      ..starting = false;
    return _Fixture(root, library, controller, receiver);
  }

  Future<void> close() async {
    controller.dispose();
    library.dispose();
    await root.delete(recursive: true);
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  bool android = true,
}) async {
  if (Platform.environment['TERAX_CAPTURE_DRAG'] == '1') {
    await tester.runAsync(() async {
      final font = FontLoader('Segoe UI');
      font.addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        File(
          'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await icons.load();
    });
  }
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: android ? TeraxTheme.build(TeraxPlatform.android) : teraxTheme(),
      home: RepaintBoundary(
        key: const ValueKey('drag-screen'),
        child: Home(controller: fixture.controller, library: fixture.library),
      ),
    ),
  );
}

Future<void> _complete(WidgetTester tester, _Fixture fixture) async {
  await tester.runAsync(() async {
    fixture.receiver.completed.complete();
    await Future<void>.delayed(const Duration(milliseconds: 2050));
  });
  await tester.pump(const Duration(seconds: 2));
  expect(find.text('Enviado a Mi PC'), findsOneWidget);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(fixture.close);
}

void main() {
  testWidgets(
    'Android preview sends with the existing controller and verified scene',
    (tester) async {
      final fixture = (await tester.runAsync(_Fixture.create))!;
      await _mount(tester, fixture, android: true);
      await tester.runAsync(() async {
        await tester.tap(find.text('reporte.txt'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      expect(find.text('O desliza el archivo hacia arriba'), findsOneWidget);
      expect(find.byType(TransferScene), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.text('Enviar a Mi PC'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      expect(find.text('Enviando a Mi PC'), findsOneWidget);
      expect(find.text('Enviado a Mi PC'), findsNothing);
      await _complete(tester, fixture);
    },
  );

  testWidgets(
    'tap document previews it and upward swipe shows transfer then sent',
    (tester) async {
      final fixture = (await tester.runAsync(_Fixture.create))!;
      await _mount(tester, fixture);
      await tester.runAsync(() async {
        await tester.tap(find.text('reporte.txt'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      expect(find.byType(SwipeCard), findsOneWidget);
      expect(find.text('O desliza el archivo hacia arriba'), findsOneWidget);
      expect(find.byType(TransferScene), findsNothing);
      await tester.runAsync(() async {
        await tester.drag(find.byType(SwipeCard), const Offset(0, -160));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      expect(find.byType(TransferScene), findsOneWidget);
      expect(find.text('Enviando a Mi PC'), findsOneWidget);
      expect(find.text('Enviado a Mi PC'), findsNothing);
      await _complete(tester, fixture);
    },
  );
  testWidgets('long press document and drop at top edge launches transfer', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_Fixture.create))!;
    await _mount(tester, fixture);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('reporte.txt')),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.byType(DragTarget<LibraryItem>), findsOneWidget);
    if (Platform.environment['TERAX_CAPTURE_DRAG'] == '1') {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump(const Duration(milliseconds: 450));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('drag-screen')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('tmp/motion').create(recursive: true);
        await File(
          'tmp/motion/drag-edge-soft.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await gesture.moveTo(const Offset(195, 40));
    await tester.pump();
    expect(find.text('Suelta para enviar a Mi PC'), findsOneWidget);
    await tester.runAsync(() async {
      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
    expect(find.byType(TransferScene), findsOneWidget);
    expect(
      tester.widget<TransferScene>(find.byType(TransferScene)).fromEdge,
      isTrue,
    );
    expect(find.text('Enviando a Mi PC'), findsOneWidget);
    await _complete(tester, fixture);
  });
  testWidgets(
    'release outside edge returns the file without sending or leaking overlays',
    (tester) async {
      final fixture = (await tester.runAsync(_Fixture.create))!;
      await _mount(tester, fixture);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('reporte.txt')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveTo(const Offset(195, 460));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.state, SendState.idle);
      expect(find.byType(TransferScene), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
}

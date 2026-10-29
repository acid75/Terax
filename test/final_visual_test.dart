import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/transfer/identity.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/ui/home.dart';

// Local rendering fixtures. Hardware/network behavior is tested separately.
class _CaptureController extends AppController {
  @override
  Future<void> send() async {
    state = SendState.sending;
    progress = .62;
    outgoingId = 'capture-outgoing';
    notifyListeners();
  }

  void repaint() => notifyListeners();
}

void main() {
  if (Platform.environment['TERAX_CAPTURE_FINAL'] != '1') return;
  setUpAll(() async {
    for (final f in {
      'Figtree': 'assets/fonts/Figtree-VariableFont_wght.ttf',
      'GeistMono': 'assets/fonts/GeistMono-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final font = FontLoader(f.key);
      font.addFont(rootBundle.load(f.value));
      await font.load();
    }
  });
  testWidgets(
    'handoff transfer and motion capture at 360 412 and 1280 with reduced motion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late Directory root;
      late File photo;
      late List<int> bytes;
      late LibraryService library;
      late ServerIdentity identity;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('terax-final-qa-');
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawPaint(Paint()..color = TeraxColors.android.illustrationLine);
        canvas.drawRect(
          const Rect.fromLTWH(0, 235, 300, 165),
          Paint()..color = TeraxColors.android.iconContainer,
        );
        canvas.drawCircle(
          const Offset(105, 105),
          32,
          Paint()..color = TeraxColors.android.iconRing,
        );
        final pic = recorder.endRecording();
        final image = await pic.toImage(300, 400);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = png!.buffer.asUint8List();
        photo = await File(
          '${root.path}/IMG_20261028_093310.png',
        ).writeAsBytes(bytes);
        image.dispose();
        pic.dispose();
        identity = const ServerIdentity('', '', '');
        library = LibraryService(android: false)..locationLabel = 'Tus fotos';
        library.items = [
          for (var i = 0; i < 12; i++)
            LibraryItem(
              id: 'image-$i',
              name: 'IMG_20261028_0933$i.png',
              isDirectory: false,
              isImage: true,
              size: photo.lengthSync(),
              modified: DateTime.now().subtract(Duration(days: i < 6 ? 0 : 1)),
              localFile: photo,
            ),
        ];
      });
      final key = GlobalKey();
      Future<void> warm() async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 35)),
          );
          await tester.pump();
        }
      }

      Future<void> capture(String name) async {
        await warm();
        expect(tester.takeException(), isNull, reason: name);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('tmp/ui-final').create(recursive: true);
          await File(
            'tmp/ui-final/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> mount(
        _CaptureController c,
        TeraxPlatform platform, {
        bool reduced = false,
        double scale = 1,
      }) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: TeraxTheme.build(platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: platform == TeraxPlatform.android
                      ? const EdgeInsets.only(top: 36, bottom: 24)
                      : EdgeInsets.zero,
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: Home(controller: c, library: library),
            ),
          ),
        );
        await warm();
      }

      _CaptureController controller(String name) => _CaptureController()
        ..starting = false
        ..peerOnline = true
        ..peer = PairingInfo(
          host: '127.0.0.1',
          port: 4040,
          token: 'a' * 64,
          fingerprint: 'b' * 64,
          name: name,
        )
        ..nearbyFingerprint = 'b' * 64;
      for (final width in [360.0, 412.0]) {
        tester.view.physicalSize = Size(width, 844);
        final c = controller('PC de casa');
        await mount(c, TeraxPlatform.android);
        await tester.runAsync(() async {
          await tester.tap(find.text(library.items.first.name));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        await tester.tap(find.text('Enviar a PC de casa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 950));
        await capture('android-${width.toInt()}-sending');
        c.state = SendState.failed;
        c.error = 'El otro equipo ya está recibiendo un archivo.';
        c.repaint();
        await tester.pump();
        await capture('android-${width.toInt()}-busy-error');
        await mount(c, TeraxPlatform.android, reduced: true, scale: 2);
        await tester.pumpAndSettle();
        await capture('android-${width.toInt()}-error-text200-reduced');
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        final dragC = controller('PC de casa');
        await mount(dragC, TeraxPlatform.android);
        final drag = await tester.startGesture(
          tester.getCenter(find.byType(LongPressDraggable<LibraryItem>).first),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await drag.moveTo(Offset(width / 2, 70));
        await tester.pump(const Duration(milliseconds: 200));
        await capture('android-${width.toInt()}-drag');
        await drag.moveTo(Offset(width / 2, 500));
        await drag.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        dragC.dispose();
      }
      tester.view.physicalSize = const Size(1280, 800);
      final c = controller('Mi Android');
      c.server = TransferServer(
        directory: root,
        identity: identity,
        name: 'PC de casa',
        token: 'c' * 64,
      );
      c.incomingVisual = IncomingProgress(
        'IMG_20261028_093310.png',
        (bytes.length * .62).round(),
        bytes.length,
        id: 'incoming',
      );
      c.incomingPreview = Uint8List.fromList(bytes);
      await mount(c, TeraxPlatform.windows);
      await tester.pump(const Duration(milliseconds: 300));
      await capture('windows-arrival');
      c.incomingVisual = IncomingProgress(
        'IMG_20261028_093310.png',
        bytes.length,
        bytes.length,
        id: 'incoming',
        stage: IncomingStage.verifying,
      );
      c.repaint();
      await tester.pump();
      await capture('windows-verifying');
      await tester.pump(const Duration(milliseconds: 220));
      c.receiveComplete = true;
      c.latestReceived = ReceivedFile(
        photo,
        'IMG_20261028_093310.png',
        photo.lengthSync(),
        id: 'incoming',
      );
      c.autoOpenDue = DateTime.now().add(const Duration(seconds: 2));
      c.repaint();
      await tester.pump();
      await capture('windows-verified');
      c.autoOpenDue = null;
      await mount(c, TeraxPlatform.windows, reduced: true);
      await tester.pumpAndSettle();
      await capture('windows-verified-reduced');
      c.receiveComplete = false;
      c.latestReceived = null;
      c.incomingFailure = 'El archivo no pasó la verificación de integridad.';
      c.repaint();
      await tester.pumpAndSettle();
      await capture('windows-integrity-error');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      library.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}

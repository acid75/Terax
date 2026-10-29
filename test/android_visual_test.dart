import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/ui/android_settings.dart';
import 'package:terax/ui/android_preview.dart';
import 'package:terax/ui/pairing.dart';

void main() {
  if (Platform.environment['TERAX_CAPTURE_ANDROID'] != '1') return;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Figtree': 'assets/fonts/Figtree-VariableFont_wght.ttf',
      'GeistMono': 'assets/fonts/GeistMono-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  for (final width in [360.0, 412.0]) {
    testWidgets('Android real screens at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late File photo;
      late LibraryService docs;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('terax-design-');
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
        final picture = recorder.endRecording();
        final image = await picture.toImage(300, 400);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        photo = await File(
          '${root.path}/IMG_20261028.jpg',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        final work = await Directory('${root.path}/Trabajo').create();
        final downloads = await Directory('${root.path}/Descargas').create();
        await File(
          '${work.path}/Factura_octubre.pdf',
        ).writeAsString('document fixture');
        await File('${work.path}/Notas reunión.md').writeAsString('Test');
        await Directory('${work.path}/2026').create();
        docs = LibraryService(
          android: false,
          roots: {
            LibraryKind.document: [work, downloads],
          },
        );
        await docs.load(LibraryKind.document);
        await docs.openFolder(
          docs.items.firstWhere((i) => i.name == 'Trabajo'),
        );
      });
      const peer = PairingInfo(
        host: '192.168.1.2',
        port: 443,
        token: 'a',
        fingerprint: 'b',
        name: 'PC de casa',
      );
      final c = AppController()
        ..starting = false
        ..peer = peer
        ..knownPeers = [
          peer,
          const PairingInfo(
            host: '192.168.1.3',
            port: 443,
            token: 'c',
            fingerprint: 'd',
            name: 'Laptop del trabajo',
          ),
        ]
        ..peerOnline = true
        ..nearbyFingerprint = 'b'
        ..proximityStatus = 'Bluetooth está apagado';
      final photos = LibraryService()
        ..locationLabel = 'Tus fotos'
        ..items = [
          for (var i = 0; i < 18; i++)
            LibraryItem(
              id: 'photo$i',
              name: 'IMG_20261028_${1000 + i}.jpg',
              isDirectory: false,
              isImage: true,
              size: 100,
              modified: DateTime.now().subtract(Duration(days: i ~/ 9)),
              localFile: photo,
            ),
        ];
      final denied = LibraryService()
        ..photoAccess = PermissionState.denied
        ..canChoosePhotos = true;
      Future<void> capture(
        String name,
        Widget screen, {
        Future<void> Function()? action,
      }) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              key: ValueKey(name),
              debugShowCheckedModeBanner: false,
              theme: TeraxTheme.build(TeraxPlatform.android),
              home: screen,
            ),
          ),
        );
        for (var frame = 0; frame < 6; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        if (action != null) {
          await action();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('tmp/handoff-phase-3').create(recursive: true);
          await File(
            'tmp/handoff-phase-3/$name-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('01-fotos', Home(controller: c, library: photos));
      await capture('05-documentos', Home(controller: c, library: docs));
      c.selected = photo;
      c.selectedName = 'IMG_20261028.jpg';
      c.selectedSize = (await tester.runAsync(photo.length))!;
      await capture(
        '03-vista-previa',
        Scaffold(
          body: SafeArea(
            child: AndroidFilePreview(
              controller: c,
              onBack: () {},
              onSend: () {},
              onDestination: () {},
            ),
          ),
        ),
      );
      await capture('07-equipos', AndroidSettings(controller: c));
      await capture(
        '06-vincular',
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConnectDialog(context, c),
              child: const Text('Vincular'),
            ),
          ),
        ),
        action: () async {
          await tester.tap(find.text('Vincular'));
        },
      );
      await capture('08-permisos', Home(controller: c, library: denied));
      await tester.pumpWidget(const SizedBox());
      photos.dispose();
      docs.dispose();
      denied.dispose();
      c.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    });
  }
}

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

class _VisualController extends AppController {
  @override
  PairingInfo get ownPairing => PairingInfo(
    host: '192.168.1.2',
    port: 443,
    token: 'a' * 64,
    fingerprint: 'b' * 64,
    name: 'Mi PC',
  );
}

void main() {
  if (Platform.environment['TERAX_CAPTURE_WINDOWS'] != '1') return;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Figtree': 'assets/fonts/Figtree-VariableFont_wght.ttf',
      'GeistMono': 'assets/fonts/GeistMono-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(rootBundle.load(font.value));
      await loader.load();
    }
  });
  testWidgets('Windows real receive, sending and settings views at 1280x800', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory root;
    late File photo;
    late LibraryService library;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('terax-windows-ui-');
      final docs = await Directory('${root.path}/Documents').create();
      final downloads = await Directory('${root.path}/Downloads').create();
      await Directory('${docs.path}/Facturas').create();
      for (final name in [
        'Contrato_servicios_2026.pdf',
        'Presupuesto_Q4.xlsx',
        'Propuesta comercial — versión revisada por dirección.docx',
        'Presentación_ventas.pptx',
        'notas.txt',
        'Inventario.csv',
        'instalador.exe',
      ]) {
        await File(
          '${docs.path}/$name',
        ).writeAsString('Archivo de prueba de interfaz.');
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawPaint(Paint()..color = TeraxColors.android.illustrationLine);
      canvas.drawCircle(
        const Offset(80, 80),
        40,
        Paint()..color = TeraxColors.android.iconRing,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 320);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      photo = await File(
        '${root.path}/IMG_20261028.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      library = LibraryService(
        android: false,
        roots: {
          LibraryKind.document: [docs, downloads],
        },
      );
      await library.load(LibraryKind.document);
      await library.openAuthorizedFolder(
        library.authorizedFolders.firstWhere((r) => r.name == 'Documents'),
      );
    });
    final c = _VisualController()
      ..starting = false
      ..peerOnline = true
      ..peer = PairingInfo(
        host: '192.168.1.10',
        port: 443,
        token: 'c' * 64,
        fingerprint: 'd' * 64,
        name: 'Mi Android',
      )
      ..nearbyFingerprint = 'd' * 64
      ..autoOpenImages = true
      ..addresses = ['192.168.1.2']
      ..address = '192.168.1.2';
    c.knownPeers = [c.peer!];
    c.server = TransferServer(
      directory: Directory('${root.path}/Documents/Terax/Recibidos'),
      identity: const ServerIdentity('', '', ''),
      name: 'Mi PC',
    );
    final pdf = library.items.firstWhere((i) => i.name.endsWith('.pdf'));
    for (final entry in [
      (photo, 'IMG_20261028_093310.png', true),
      (pdf.localFile!, 'Factura_octubre_2026.pdf', true),
      (pdf.localFile!, 'Presupuesto_Q4.xlsx', false),
      (photo, 'Screenshot_20261028.png', true),
    ]) {
      c.history.add(
        HistoryEntry(
          name: entry.$2,
          size: 1024,
          incoming: entry.$3,
          file: entry.$1,
          time: DateTime(2026, 10, 28, 10, 42),
        ),
      );
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: TeraxTheme.build(TeraxPlatform.windows),
          home: Home(controller: c, library: library),
        ),
      ),
    );
    Future<void> capture(String name) async {
      for (var frame = 0; frame < 6; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('tmp/handoff-phase-4').create(recursive: true);
        await File(
          'tmp/handoff-phase-4/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('09-recibir-1280');
    c.setAccepting(false);
    await capture('09-recepcion-pausada-1280');
    c.setAccepting(true);
    await tester.tap(find.text('Enviar al teléfono'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contrato_servicios_2026.pdf').first);
    await capture('11-enviar-1280');
    await tester.tap(find.text('Equipos y ajustes'));
    await tester.pumpAndSettle();
    await capture('ajustes-1280');
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    c.dispose();
    await tester.runAsync(() => root.delete(recursive: true));
  });
}

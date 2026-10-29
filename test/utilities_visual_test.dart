import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/sharing/shared_message.dart';
import 'package:terax/sharing/transfer_sounds.dart';
import 'package:terax/transfer/history_store.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/transfer/transfer_queue.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/ui/history_page.dart';
import 'package:terax/ui/queue_panel.dart';

class _History implements TransferHistoryStore {
  @override
  Future<List<HistoryEntry>> load() async => [];
  @override
  Future<void> save(List<HistoryEntry> e) async {}
}

class _Controller extends AppController {
  _Controller(Directory root)
    : super(
        documentsDirectory: () async => root,
        historyStore: _History(),
        sounds: TransferSounds(directory: () async => root),
      );
  @override
  Future<void> send() async {
    state = SendState.sending;
    outgoingId = 'fixture-out';
    progress = .62;
    notifyListeners();
  }

  void repaint() => notifyListeners();
}

void main() {
  if (Platform.environment['TERAX_CAPTURE_UTILITIES'] != '1') return;
  setUpAll(() async {
    for (final f in {
      'Figtree': 'assets/fonts/Figtree-VariableFont_wght.ttf',
      'GeistMono': 'assets/fonts/GeistMono-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(f.key);
      loader.addFont(rootBundle.load(f.value));
      await loader.load();
    }
  });
  testWidgets('utilities and real file flight visual fixtures', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late Directory root;
    late File doc;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('terax-utility-visual-');
      doc = await File(
        '${root.path}/Plan de trabajo.txt',
      ).writeAsString('Documento de prueba de interfaz.');
    });
    final library = LibraryService(android: false)
      ..kind = LibraryKind.document
      ..locationLabel = 'Documentos'
      ..items = [
        LibraryItem(
          id: doc.path,
          name: 'Plan de trabajo.txt',
          isDirectory: false,
          isImage: false,
          size: 31,
          modified: DateTime.now(),
          localFile: doc,
        ),
      ];
    final boundaryKey = GlobalKey(), nav = GlobalKey<NavigatorState>();
    Future<void> warm() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 35)),
        );
        await tester.pump();
      }
    }

    Future<void> capture(String name) async {
      await warm();
      expect(tester.takeException(), isNull, reason: name);
      final b = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final im = await b.toImage(pixelRatio: 2);
        final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
        await Directory('tmp/utilities-visual').create(recursive: true);
        await File(
          'tmp/utilities-visual/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        im.dispose();
      });
    }

    Future<void> mount(
      _Controller c,
      TeraxPlatform platform, {
      bool reduced = false,
      double scale = 1,
    }) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: nav,
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
            home: Home(
              controller: c,
              library: library,
              chooseFiles: () async => library.items,
            ),
          ),
        ),
      );
      await warm();
    }

    _Controller make([String name = 'PC de casa']) => _Controller(root)
      ..starting = false
      ..peerOnline = true
      ..peer = PairingInfo(
        host: '127.0.0.1',
        port: 4040,
        token: 'a' * 64,
        fingerprint: 'b' * 64,
        name: name,
      );
    for (final width in [360.0, 412.0]) {
      tester.view.physicalSize = Size(width, 844);
      final c = make();
      await mount(c, TeraxPlatform.android);
      await capture('android-${width.toInt()}-actions');
      await tester.pump(const Duration(milliseconds: 1400));
      await capture('android-${width.toInt()}-glow-bright');
      await tester.pump(const Duration(milliseconds: 1400));
      await capture('android-${width.toInt()}-glow-soft');
      await tester.tap(find.text('Texto y enlaces'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/propuesta',
      );
      await tester.tap(find.text('Enlace').last);
      await tester.pump();
      await capture('android-${width.toInt()}-composer');
      await tester.tap(find.text('Continuar'));
      await warm();
      for (var i = 0; i < 40 && c.selectedMessage == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      expect(c.selectedMessage?.kind, SharedMessageKind.link, reason: c.error);
      await capture('android-${width.toInt()}-link-preview');
      await tester.tap(find.text('Enviar a PC de casa'));
      await tester.pump();
      await tester.pump();
      for (var frame = 0; frame <= 6; frame++) {
        if (frame > 0) await tester.pump(const Duration(milliseconds: 200));
        await capture('android-${width.toInt()}-wave-${frame * 200}');
      }
      await tester.pump(const Duration(milliseconds: 200));
      c.state = SendState.idle;
      c.outgoingId = null;
      c.incomingVisual = const IncomingProgress(
        'Mensaje.terax-message.json',
        10,
        10,
        id: 'received',
      );
      c.receiveComplete = true;
      c.receivedMessage = SharedMessage.text(
        'Hola desde la PC.\nEste texto se conserva y puedes copiarlo.',
      );
      c.latestReceived = ReceivedFile(
        doc,
        'Mensaje.terax-message.json',
        10,
        id: 'received',
      );
      c.repaint();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await capture('android-${width.toInt()}-text-arrival');
      await tester.pumpAndSettle();
      await mount(c, TeraxPlatform.android, reduced: true, scale: 2);
      await tester.pumpAndSettle();
      await capture('android-${width.toInt()}-text200-reduced');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }
    tester.view.physicalSize = const Size(1280, 800);
    final c = make('Mi Android');
    await mount(c, TeraxPlatform.windows);
    await tester.pump(const Duration(milliseconds: 1400));
    await capture('windows-glow-bright');
    await tester.pump(const Duration(milliseconds: 1400));
    await capture('windows-glow-soft');
    c.incomingVisual = const IncomingProgress(
      'Texto.terax-message.json',
      10,
      10,
      id: 'windows-in',
    );
    c.receiveComplete = true;
    c.receivedMessage = SharedMessage.link('https://example.com/documento');
    c.latestReceived = ReceivedFile(
      doc,
      'Texto.terax-message.json',
      10,
      id: 'windows-in',
    );
    await mount(c, TeraxPlatform.windows);
    for (var frame = 0; frame <= 6; frame++) {
      if (frame > 0) await tester.pump(const Duration(milliseconds: 200));
      await capture('windows-arrival-${frame * 200}');
    }
    await capture('windows-link-received');
    c.history.add(
      HistoryEntry(
        name: 'Plan de trabajo.txt',
        size: 31,
        incoming: true,
        file: doc,
        time: DateTime.now(),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => HistoryPage(controller: c)),
    );
    await tester.pumpAndSettle();
    await capture('windows-history');
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    final queue = TransferQueue(
      send: (_) async => const QueueOutcome.sent(),
      canStart: () => false,
      cancelCurrent: () {},
    );
    queue.add([
      library.items.first,
      LibraryItem(
        id: 'two',
        name: 'Resumen.pdf',
        isDirectory: false,
        isImage: false,
        size: 12000,
        modified: DateTime.now(),
        localFile: doc,
      ),
    ]);
    await queue.start();
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => TransferQueuePage(queue: queue, controller: c),
      ),
    );
    await tester.pumpAndSettle();
    await capture('windows-queue');
    await tester.runAsync(() async {
      await c.sounds.outgoing();
      await c.sounds.incoming();
      for (final pair in {
        'departure-v6.mp3': 'salida.mp3',
        'arrival-v6.mp3': 'entrada.mp3',
      }.entries) {
        await File(
          '${root.path}/transfer_sounds/${pair.key}',
        ).copy('tmp/utilities-visual/${pair.value}');
      }
    });
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    c.dispose();
    library.dispose();
    await tester.runAsync(() => root.delete(recursive: true));
  });
}

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/ui/library_browser.dart';
import 'package:terax/ui/transfer_scene.dart';
import 'package:terax/ui/transfer_view_state.dart';

class _OpenRecorder extends AppController {
  final opened = <String>[];
  @override
  Future<void> openFile(File file) async {
    opened.add(file.path);
  }
}

PairingInfo get _peer => PairingInfo(
  host: '127.0.0.1',
  port: 4040,
  token: 'a' * 64,
  fingerprint: 'b' * 64,
  name: 'PC de casa',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'nine presentation stages never infer success from progress or preview',
    () {
      final c = AppController()
        ..starting = false
        ..peer = _peer;
      addTearDown(c.dispose);
      TransferViewStage tx() => TransferViewState.from(c, outbound: true).stage;
      TransferViewStage rx() =>
          TransferViewState.from(c, outbound: false).stage;
      c.state = SendState.preparing;
      c.progress = 1;
      expect(tx(), TransferViewStage.preparingSend);
      expect(rx(), TransferViewStage.preparingReceive);
      c.state = SendState.sending;
      c.progress = .62;
      expect(tx(), TransferViewStage.transferring);
      c.progress = .99;
      expect(tx(), TransferViewStage.verifying);
      expect(TransferViewState.from(c, outbound: true).success, false);
      c.progress = 1;
      expect(tx(), TransferViewStage.verifying);
      c.state = SendState.complete;
      expect(tx(), TransferViewStage.sent);
      c.incomingVisual = const IncomingProgress(
        'a.txt',
        100,
        100,
        id: 'one',
        stage: IncomingStage.verifying,
      );
      expect(rx(), TransferViewStage.verifying);
      c.receiveComplete = true;
      expect(rx(), TransferViewStage.received);
      c.receiveComplete = false;
      c.receiveCancelled = true;
      expect(rx(), TransferViewStage.cancelled);
      c.incomingFailure = 'Se interrumpió la recepción.';
      expect(rx(), TransferViewStage.failed);
      c.incomingFailure = 'El archivo no pasó la verificación de integridad.';
      expect(rx(), TransferViewStage.integrityError);
      c.state = SendState.failed;
      c.cancelRequested = true;
      c.error = 'Envío cancelado.';
      expect(tx(), TransferViewStage.cancelled);
      c.error = 'Error de integridad.';
      expect(tx(), TransferViewStage.integrityError);
    },
  );
  test(
    'choosing a missing next file cannot retain previous sent success or selection',
    () async {
      final gate = Completer<File>();
      final c = AppController()
        ..state = SendState.complete
        ..outgoingId = 'old-sent'
        ..selected = File('old.txt')
        ..selectedName = 'old.txt';
      addTearDown(c.dispose);
      final item = LibraryItem(
        id: 'missing',
        name: 'missing.txt',
        isDirectory: false,
        isImage: false,
        size: 1,
        modified: DateTime.now(),
        resolver: () => gate.future,
      );
      final pending = c.selectLibraryItem(item);
      final beforeId = c.outgoingId;
      final beforeState = c.state;
      gate.completeError(StateError('El archivo ya no está disponible.'));
      await pending;
      expect(beforeId, isNull);
      expect(beforeState, SendState.idle);
      expect(c.selected, isNull);
      expect(c.canSend, false);
      expect(c.error, isNotNull);
    },
  );
  test(
    'multiple linked devices never attribute an incoming file to the selected peer',
    () {
      final c = AppController()
        ..peer = _peer
        ..knownPeers = [
          PairingInfo(
            host: '127.0.0.2',
            port: 4040,
            token: 'c' * 64,
            fingerprint: 'd' * 64,
            name: 'Otro equipo',
          ),
        ]
        ..incomingVisual = const IncomingProgress('foto.png', 3, 5, id: 'one');
      addTearDown(c.dispose);
      expect(c.incomingSourceName, isNull);
      expect(
        TransferViewState.from(c, outbound: false).title,
        'Recibiendo archivo',
      );
      c.state = SendState.sending;
      c.outgoingPeerName = 'Destino original';
      expect(
        TransferViewState.from(c, outbound: true).title,
        'Enviando a Destino original',
      );
    },
  );
  testWidgets(
    'verification and integrity failure stay visible without success or open',
    (tester) async {
      final c = AppController()
        ..starting = false
        ..incomingVisual = const IncomingProgress(
          'Informe.pdf',
          100,
          100,
          id: 'one',
          stage: IncomingStage.verifying,
        );
      addTearDown(c.dispose);
      Widget view() => MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.windows),
        home: Scaffold(
          body: TransferScene(controller: c, outbound: false, onDismiss: () {}),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Verificando…'), findsOneWidget);
      expect(find.text('Recibido y verificado'), findsNothing);
      expect(find.text('Abrir'), findsNothing);
      c.incomingFailure = 'El archivo no pasó la verificación de integridad.';
      c.receiveCancelled = true;
      await tester.pumpWidget(view());
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Error de integridad'), findsOneWidget);
      expect(find.text('Abrir'), findsNothing);
      expect(find.text('Recibido y verificado'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, false);
      c.incomingFailure = 'No se pudo borrar un archivo incompleto.';
      await tester.pumpWidget(view());
      expect(
        find.text('No se pudo borrar un archivo incompleto.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'success auto-dismiss is delayed and cannot dismiss a later failure',
    (tester) async {
      final c = AppController()
        ..starting = false
        ..state = SendState.complete
        ..outgoingId = 'one'
        ..selectedName = 'nota.txt';
      addTearDown(c.dispose);
      var dismissed = 0;
      Widget view() => MaterialApp(
        home: Scaffold(
          body: TransferScene(
            controller: c,
            outbound: true,
            compact: true,
            autoDismiss: true,
            onDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pump(const Duration(milliseconds: 1900));
      expect(dismissed, 0);
      await tester.pump(const Duration(milliseconds: 110));
      expect(dismissed, 1);
      c.outgoingId = 'two';
      c.state = SendState.failed;
      c.error = 'Sin conexión';
      await tester.pumpWidget(view());
      await tester.pump(const Duration(seconds: 3));
      expect(dismissed, 1);
    },
  );
  testWidgets(
    'Android keeps library under transfer at 320dp and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController()
        ..starting = false
        ..peer = _peer
        ..peerOnline = true
        ..state = SendState.sending
        ..selectedName = 'Documento con nombre largo.pdf'
        ..selectedSize = 1024
        ..progress = .6
        ..outgoingId = 'one';
      final library = LibraryService()..locationLabel = 'Tus fotos';
      addTearDown(c.dispose);
      addTearDown(library.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Home(controller: c, library: library),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LibraryBrowser), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.textContaining('Enviando a'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, false);
    },
  );
  testWidgets('Windows receipt keeps navigation visible', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = AppController()
      ..starting = false
      ..peer = _peer
      ..incomingVisual = const IncomingProgress(
        'nota.txt',
        6,
        10,
        id: 'incoming',
      );
    final l = LibraryService();
    addTearDown(c.dispose);
    addTearDown(l.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.windows),
        home: Home(controller: c, library: l),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enviar al teléfono'), findsOneWidget);
    expect(find.text('Equipos y ajustes'), findsOneWidget);
    expect(find.text('Recibiendo de PC de casa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'outgoing auto-dismiss preserves a simultaneous verified receipt',
    (tester) async {
      final c = AppController()
        ..starting = false
        ..peer = _peer
        ..state = SendState.complete
        ..outgoingId = 'sent'
        ..selectedName = 'out.txt';
      final l = LibraryService();
      addTearDown(c.dispose);
      addTearDown(l.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget home() => MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.windows),
        home: Home(controller: c, library: l),
      );
      await tester.pumpWidget(home());
      await tester.pump(const Duration(milliseconds: 1500));
      c.incomingVisual = const IncomingProgress('in.txt', 1, 1, id: 'received');
      c.receiveComplete = true;
      c.latestReceived = ReceivedFile(
        File('in.txt'),
        'in.txt',
        1,
        id: 'received',
      );
      c.autoOpenDue = DateTime.now().add(const Duration(seconds: 3));
      await tester.pumpWidget(home());
      expect(find.text('Recibido y verificado'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.outgoingId, isNull);
      expect(c.latestReceived?.id, 'received');
      expect(c.incomingVisual?.id, 'received');
      expect(c.autoOpenDue, isNotNull);
      expect(find.text('Recibido y verificado'), findsOneWidget);
      expect(find.text('No abrir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'per-file No abrir cancels countdown without disabling future openings',
    () async {
      final root = await Directory.systemTemp.createTemp('terax-open-test-');
      addTearDown(() => root.delete(recursive: true));
      final file = await File(
        '${root.path}/nota.txt',
      ).writeAsString('nota real');
      final c = _OpenRecorder()
        ..autoOpenImages = true
        ..receiveComplete = true
        ..latestReceived = ReceivedFile(file, 'nota.txt', 9, id: 'one');
      addTearDown(c.dispose);
      final pending = c.prepareAutomaticOpening();
      for (var i = 0; i < 20 && c.autoOpenDue == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(c.autoOpenDue, isNotNull);
      c.cancelAutomaticOpen();
      await pending;
      expect(c.opened, isEmpty);
      expect(c.autoOpenImages, true);
      await c.prepareAutomaticOpening();
      expect(c.opened, [file.path]);
      expect(c.autoOpenDue, isNull);
    },
  );
  test(
    'unverified, forbidden and invalid files never schedule opening',
    () async {
      final root = await Directory.systemTemp.createTemp('terax-open-test-');
      addTearDown(() => root.delete(recursive: true));
      final file = await File(
        '${root.path}/fake.pdf',
      ).writeAsBytes([0x4d, 0x5a, 0, 0]);
      final c = _OpenRecorder()
        ..autoOpenImages = true
        ..latestReceived = ReceivedFile(file, 'fake.pdf', 4);
      addTearDown(c.dispose);
      await c.prepareAutomaticOpening();
      expect(c.autoOpenDue, isNull);
      expect(c.opened, isEmpty);
      c.receiveComplete = true;
      await c.prepareAutomaticOpening();
      expect(c.autoOpenDue, isNull);
      expect(c.automaticOpenNotice, isNotNull);
      c.latestReceived = ReceivedFile(file, 'macro.docm', 4);
      await c.prepareAutomaticOpening();
      expect(c.autoOpenDue, isNull);
      expect(c.opened, isEmpty);
    },
  );
  testWidgets(
    'manual open failure preserves verified receipt and recovery actions',
    (tester) async {
      const channel = MethodChannel('terax/files');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => false);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final c = AppController()
        ..receiveComplete = true
        ..latestReceived = ReceivedFile(File('missing.txt'), 'missing.txt', 1)
        ..incomingVisual = const IncomingProgress(
          'missing.txt',
          1,
          1,
          id: 'one',
        );
      addTearDown(c.dispose);
      await c.openFile(c.latestReceived!.file);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.windows),
          home: Scaffold(
            body: TransferScene(
              controller: c,
              outbound: false,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recibido y verificado'), findsOneWidget);
      expect(find.textContaining('Se guardó, pero'), findsOneWidget);
      expect(find.text('Mostrar en carpeta'), findsOneWidget);
      expect(c.receiveComplete, true);
    },
  );
}

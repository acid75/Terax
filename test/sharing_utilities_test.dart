import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/sharing/shared_message.dart';
import 'package:terax/sharing/android_share_bridge.dart';
import 'package:terax/sharing/transfer_sounds.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/transfer/history_store.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/ui/message_composer.dart';

class _History implements TransferHistoryStore {
  final pending = Completer<List<HistoryEntry>>();
  List<HistoryEntry>? saved;
  @override
  Future<List<HistoryEntry>> load() => pending.future;
  @override
  Future<void> save(List<HistoryEntry> entries) async {
    saved = List.of(entries);
  }
}

class _ReadOnlyHistory implements TransferHistoryStore {
  @override
  Future<List<HistoryEntry>> load() async => [
    HistoryEntry(
      name: 'conservar.txt',
      size: 1,
      incoming: true,
      file: File('conservar.txt'),
      time: DateTime.now(),
    ),
  ];
  @override
  Future<void> save(List<HistoryEntry> items) async {
    throw const FileSystemException('Solo lectura');
  }
}

class _Receiver extends TransferClient {
  final ready = Completer<void>(), complete = Completer<void>();
  SharedMessage? message;
  @override
  Future<void> send(
    File file,
    PairingInfo peer, {
    ProgressCallback? onProgress,
    void Function(TransferOffer)? onReady,
    String? name,
    String? preview,
  }) async {
    message = SharedMessage.decode(await file.readAsBytes());
    onReady?.call(
      TransferOffer(id: 'a' * 32, name: name!, size: await file.length()),
    );
    onProgress?.call(.5);
    ready.complete();
    await complete.future;
    onProgress?.call(1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'clear waits for initial history load and cannot resurrect old records',
    () async {
      final store = _History();
      final c = AppController(historyStore: store);
      addTearDown(c.dispose);
      final loading = c.loadHistory();
      final clearing = c.clearHistory();
      expect(store.saved, isNull);
      store.pending.complete([
        HistoryEntry(
          name: 'old.txt',
          size: 1,
          incoming: true,
          file: File('old.txt'),
          time: DateTime.now(),
        ),
      ]);
      await loading;
      await clearing;
      expect(c.history, isEmpty);
      expect(store.saved, isEmpty);
    },
  );
  test(
    'failed history clearing restores the list and reports failure',
    () async {
      final c = AppController(historyStore: _ReadOnlyHistory());
      addTearDown(c.dispose);
      await c.loadHistory();
      expect(await c.clearHistory(), false);
      expect(c.history.single.name, 'conservar.txt');
      expect(c.notice, contains('No se pudo borrar'));
    },
  );
  test(
    'a text message uses verified file transport and only then persists history',
    () async {
      final root = await Directory.systemTemp.createTemp('terax-message-flow-');
      addTearDown(() => root.delete(recursive: true));
      final store = _History()..pending.complete([]);
      final receiver = _Receiver();
      final sounds = TransferSounds(directory: () async => root);
      await sounds.setEnabled(false);
      final c =
          AppController(
              historyStore: store,
              documentsDirectory: () async => root,
              client: receiver,
              sounds: sounds,
            )
            ..starting = false
            ..peerOnline = true
            ..peer = PairingInfo(
              host: '127.0.0.1',
              port: 4040,
              token: 'b' * 64,
              fingerprint: 'c' * 64,
              name: 'Mi PC',
            );
      addTearDown(c.dispose);
      final item = await c.createMessage(
        SharedMessage.text('Hola 👋\nDesde Terax'),
      );
      final sending = c.sendLibraryItem(item);
      await receiver.ready.future;
      expect(receiver.message?.text, 'Hola 👋\nDesde Terax');
      expect(c.selectedMessage?.kind, SharedMessageKind.text);
      expect(c.history, isEmpty);
      expect(store.saved, isNull);
      receiver.complete.complete();
      await sending;
      await Future<void>.delayed(Duration.zero);
      expect(c.state, SendState.complete);
      expect(c.history.length, 1);
      expect(store.saved?.single.name, item.name);
    },
  );
  testWidgets(
    'individual Downloads item opens preview without authorizing a folder',
    (tester) async {
      late Directory root;
      late File file;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('terax-downloads-');
        file = await File(
          '${root.path}/reporte.txt',
        ).writeAsString('Documento de Descargas');
      });
      final store = _History()..pending.complete([]);
      final c = AppController(historyStore: store)
        ..starting = false
        ..peerOnline = true
        ..peer = PairingInfo(
          host: '127.0.0.1',
          port: 4040,
          token: 'b' * 64,
          fingerprint: 'c' * 64,
          name: 'PC de casa',
        );
      final library = LibraryService();
      final item = LibraryItem(
        id: file.path,
        name: 'reporte.txt',
        isDirectory: false,
        isImage: false,
        size: 20,
        modified: DateTime.now(),
        localFile: file,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: Home(
            controller: c,
            library: library,
            chooseFiles: () async => [item],
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Archivos'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('O desliza el archivo hacia arriba'), findsOneWidget);
      expect(c.selected?.path, file.path);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      library.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets(
    'clipboard is read only when Paste is pressed and retains message content',
    (tester) async {
      var reads = 0;
      SharedMessage? result;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              reads++;
              return {'text': 'Hola copiado'};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showMessageComposer(context);
                },
                child: const Text('Componer'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Componer'));
      await tester.pumpAndSettle();
      expect(reads, 0);
      await tester.tap(find.text('Pegar del portapapeles'));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('Hola copiado'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(result?.text, 'Hola copiado');
    },
  );
  testWidgets(
    'Android sharing keeps accompanying text and file together in queue',
    (tester) async {
      late Directory root;
      late File file;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('terax-combined-');
        file = await File('${root.path}/reporte.txt').writeAsString('archivo');
      });
      final inbox = StreamController<SharedContent>();
      final store = _History()..pending.complete([]);
      final c =
          AppController(
              historyStore: store,
              documentsDirectory: () async => root,
            )
            ..starting = false
            ..peer = PairingInfo(
              host: '127.0.0.1',
              port: 4040,
              token: 'b' * 64,
              fingerprint: 'c' * 64,
              name: 'PC de casa',
            );
      final library = LibraryService();
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: Home(
            controller: c,
            library: library,
            sharedContent: inbox.stream,
          ),
        ),
      );
      inbox.add(
        SharedContent(
          text: 'https://example.com/archivo',
          files: [
            LibraryItem(
              id: file.path,
              name: 'reporte.txt',
              isDirectory: false,
              isImage: false,
              size: 7,
              modified: DateTime.now(),
              localFile: file,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incluir texto'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Continuar'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 10 && find.text('Añadir y enviar').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
      expect(find.text('Enlace'), findsOneWidget);
      expect(find.text('reporte.txt'), findsOneWidget);
      await tester.tap(find.text('Añadir y enviar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cola de envíos (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Enlace'), findsOneWidget);
      expect(find.text('reporte.txt'), findsOneWidget);
      expect(c.selected, isNull);
      c.peer = PairingInfo(
        host: '127.0.0.2',
        port: 4040,
        token: 'd' * 64,
        fingerprint: 'e' * 64,
        name: 'Otro equipo',
      );
      c.peerOnline = true;
      c.clearMessage();
      await tester.pump();
      expect(
        find.text('Selecciona PC de casa en Equipos y ajustes para continuar.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Continuar'))
            .onPressed,
        isNull,
      );
      expect(c.selected, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await inbox.close();
        c.dispose();
        library.dispose();
        await root.delete(recursive: true);
      });
      await tester.pump();
    },
  );
}

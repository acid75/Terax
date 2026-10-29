import 'dart:io';
import 'package:flutter/material.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/transfer/identity.dart';
import 'package:terax/ui/windows_parts.dart';
import 'package:terax/ui/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/ui/windows_browser.dart';
import 'package:terax/ui/components/terax_components.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/ui/home.dart';

class _DesktopActions extends AppController {
  File? opened;
  String? sent;
  @override
  Future<void> sendLibraryItem(LibraryItem item) async {
    sent = item.name;
    picking = true;
  }

  int effects = 0;
  @override
  Future<void> openFile(File file) async {
    opened = file;
  }

  @override
  Future<bool> showDesktopWave({bool force = false}) async {
    effects++;
    return true;
  }

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
  testWidgets(
    'Windows sidebar and unavailable receive state expose actual readiness',
    (tester) async {
      final c = AppController()..starting = false;
      final library = LibraryService();
      addTearDown(c.dispose);
      addTearDown(library.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.windows),
          home: Home(controller: c, library: library),
        ),
      );
      expect(find.text('Enviar al teléfono'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Guardado en este equipo'), findsOneWidget);
      expect(find.text('Conexión no disponible'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Windows file keyboard selection searches, blocks oversize and sends selected identity',
    (tester) async {
      final c = AppController()
        ..starting = false
        ..peerOnline = true
        ..peer = const PairingInfo(
          host: '127.0.0.1',
          port: 443,
          token: 'a',
          fingerprint: 'b',
          name: 'Mi Android',
        );
      final library = LibraryService()
        ..kind = LibraryKind.document
        ..locationLabel = 'Documentos'
        ..items = [
          for (final entry in [('uno.txt', 10), ('dos.zip', 1500000000)])
            LibraryItem(
              id: entry.$1,
              name: entry.$1,
              isDirectory: false,
              isImage: false,
              size: entry.$2,
              modified: DateTime.now(),
            ),
        ];
      addTearDown(c.dispose);
      addTearDown(library.dispose);
      final sent = <String>[];
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.windows),
          home: Scaffold(
            body: WindowsBrowser(
              controller: c,
              library: library,
              onSettings: () {},
              onSend: (item) {
                sent.add(item.id);
                c.picking = true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('uno.txt').first);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TeraxPrimaryButton>(find.byType(TeraxPrimaryButton))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('El máximo es 1 GB.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(sent, ['uno.txt']);
      c.picking = false;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'dos');
      await tester.pump();
      expect(find.text('uno.txt'), findsNothing);
      expect(find.text('dos.zip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('narrow Windows keeps navigation and adapts text200', (
    tester,
  ) async {
    final c = AppController()..starting = false;
    final library = LibraryService();
    addTearDown(c.dispose);
    addTearDown(library.dispose);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.windows),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Home(controller: c, library: library),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Abrir navegación'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar al teléfono'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'paused receiving resumes and saved history opens the real entry',
    (tester) async {
      late Directory historyRoot;
      await tester.runAsync(() async {
        historyRoot = await Directory.systemTemp.createTemp(
          'terax-history-ui-',
        );
        for (var i = 0; i < 14; i++) {
          await File(
            '${historyRoot.path}/entrada $i.txt',
          ).writeAsString('entrada real');
        }
      });
      addTearDown(() => historyRoot.delete(recursive: true));
      final c = _DesktopActions()..starting = false;
      c.server = TransferServer(
        directory: Directory('test/Recibidos'),
        identity: const ServerIdentity('', '', ''),
        name: 'Mi PC',
      )..accepting = false;
      c.history.addAll([
        for (var i = 0; i < 14; i++)
          HistoryEntry(
            name: 'entrada $i.txt',
            size: 1024,
            incoming: i.isEven,
            file: File('${historyRoot.path}/entrada $i.txt'),
            time: DateTime(2026, 10, 28, 10, i),
          ),
      ]);
      final library = LibraryService();
      addTearDown(library.dispose);
      addTearDown(c.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.windows),
          home: Home(controller: c, library: library),
        ),
      );
      expect(find.text('Recepción pausada'), findsWidgets);
      await tester.tap(find.text('Activar recepción'));
      await tester.pump();
      expect(c.server!.accepting, isTrue);
      expect(find.text('Listo para recibir'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(TextButton, 'Abrir').first);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      expect(c.opened!.path, File('${historyRoot.path}/entrada 0.txt').path);
      await tester.drag(
        find.descendant(
          of: find.byType(WindowsHistory),
          matching: find.byType(ListView),
        ),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.text('entrada 9.txt'), findsOneWidget);
      expect(find.text('entrada 10.txt'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop settings dialog fits text200 and only offers in-app wave',
    (tester) async {
      final c = _DesktopActions()..starting = false;
      addTearDown(c.dispose);
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.windows),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTeraxSettings(context, c),
                child: const Text('Ajustes'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Copiar código'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Probar efecto de escritorio'), findsNothing);
      await tester.ensureVisible(find.text('Onda de transferencia'));
      expect(c.effects, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Enter opens a real folder and keyboard selection continues inside it',
    (tester) async {
      late Directory root;
      late LibraryService library;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('terax-desktop-folder-');
        final child = await Directory('${root.path}/Facturas').create();
        await File('${child.path}/reporte.txt').writeAsString('test');
        library = LibraryService(
          android: false,
          roots: {
            LibraryKind.document: [root],
          },
        );
        await library.load(LibraryKind.document);
      });
      final c = _DesktopActions()
        ..starting = false
        ..peerOnline = true
        ..peer = const PairingInfo(
          host: '127.0.0.1',
          port: 443,
          token: 'a',
          fingerprint: 'b',
          name: 'Mi Android',
        );
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.windows),
          home: Home(controller: c, library: library),
        ),
      );
      await tester.tap(find.text('Enviar al teléfono'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facturas'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('reporte.txt'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(c.sent, 'reporte.txt');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      library.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets('CtrlF works directly after entering send from the sidebar', (
    tester,
  ) async {
    final c = AppController()..starting = false;
    final library = LibraryService();
    addTearDown(c.dispose);
    addTearDown(library.dispose);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.windows),
        home: Home(controller: c, library: library),
      ),
    );
    await tester.tap(find.text('Enviar al teléfono'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
  });
  testWidgets(
    'sending stays usable at 320dp with text200 and a long filename',
    (tester) async {
      final c = AppController()
        ..starting = false
        ..peerOnline = true
        ..peer = const PairingInfo(
          host: '127.0.0.1',
          port: 443,
          token: 'a',
          fingerprint: 'b',
          name: 'Mi Android',
        );
      final library = LibraryService()
        ..kind = LibraryKind.document
        ..items = [
          LibraryItem(
            id: 'one',
            name: 'Contrato de servicios con un nombre muy largo.pdf',
            isDirectory: false,
            isImage: false,
            size: 2,
            modified: DateTime.now(),
          ),
        ];
      addTearDown(c.dispose);
      addTearDown(library.dispose);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.windows),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: WindowsBrowser(
              controller: c,
              library: library,
              onSettings: () {},
              onSend: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text(library.items.single.name).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Enviar a Mi Android'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

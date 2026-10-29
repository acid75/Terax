import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/ui/library_browser.dart';

import 'package:terax/app_controller.dart';
import 'package:terax/ui/android_settings.dart';
import 'package:terax/ui/pairing.dart';
import 'package:terax/ui/android_preview.dart';
import 'package:terax/ui/components/terax_components.dart';
import 'package:terax/transfer/protocol.dart';

class _PhotosAfterSettings extends LibraryService {
  _PhotosAfterSettings() : super(android: false) {
    photoAccess = PermissionState.denied;
  }
  int refreshes = 0;
  @override
  Future<void> load(LibraryKind kind, {bool requestPermission = false}) async {
    refreshes++;
    photoAccess = PermissionState.authorized;
    locationLabel = 'Tus fotos';
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'inline search replaces tabs, filters and restores the same library',
    (tester) async {
      final service = LibraryService()
        ..items = [
          for (final name in ['uno.jpg', 'dos.jpg'])
            LibraryItem(
              id: name,
              name: name,
              isDirectory: false,
              isImage: true,
              size: 2,
              modified: DateTime.now(),
            ),
        ];
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: Scaffold(
            body: LibraryBrowser(
              service: service,
              onPreview: (_) {},
              canDrag: false,
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Hoy'), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar fotos'));
      await tester.pumpAndSettle();
      expect(find.text('Documentos'), findsNothing);
      await tester.enterText(find.byType(TextField), 'uno');
      await tester.pump();
      expect(find.text('dos.jpg'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Documentos'), findsOneWidget);
      expect(find.text('dos.jpg'), findsOneWidget);
    },
  );
  testWidgets('empty granted photo library does not ask for permission again', (
    tester,
  ) async {
    final service = LibraryService()..locationLabel = 'Tus fotos';
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.android),
        home: Scaffold(
          body: LibraryBrowser(
            service: service,
            onPreview: (_) {},
            canDrag: false,
          ),
        ),
      ),
    );
    expect(find.text('Todavía no hay fotos'), findsOneWidget);
    expect(find.text('Permitir acceso a fotos'), findsNothing);
  });
  testWidgets(
    'Android settings deduplicates identity and exposes a slow BLE action',
    (tester) async {
      const peer = PairingInfo(
        host: '192.168.1.10',
        port: 443,
        token: 'a',
        fingerprint: 'b',
        name: 'PC de casa',
      );
      final c = AppController()
        ..peer = peer
        ..knownPeers = [peer, peer]
        ..peerOnline = true
        ..starting = false
        ..proximityWorking = true;
      addTearDown(c.dispose);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: AndroidSettings(controller: c),
          ),
        ),
      );
      expect(find.text('PC de casa'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Bluetooth tarda en responder'), findsOneWidget);
      expect(find.text('Abrir permisos'), findsOneWidget);
      expect(c.proximityWorking, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Android pairing code failure stays visible and does not authorize a peer',
    (tester) async {
      final c = AppController()..starting = false;
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showConnectDialog(context, c),
                child: const Text('Vincular'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Vincular'));
      await tester.pumpAndSettle();
      expect(find.text('Vincula tu PC'), findsOneWidget);
      await tester.ensureVisible(find.text('Pegar código de conexión'));
      await tester.tap(find.text('Pegar código de conexión'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'incorrecto');
      await tester.ensureVisible(find.text('Conectar'));
      await tester.tap(find.text('Conectar'));
      await tester.pumpAndSettle();
      expect(c.peer, isNull);
      expect(find.textContaining('código'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Android photo library at 320dp and text200 preserves controls', (
    tester,
  ) async {
    final service = LibraryService()
      ..locationLabel = 'Tus fotos'
      ..items = [
        LibraryItem(
          id: 'one',
          name: 'nombre de archivo largo.jpg',
          isDirectory: false,
          isImage: true,
          size: 2,
          modified: DateTime.now(),
        ),
      ];
    addTearDown(service.dispose);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: LibraryBrowser(
            service: service,
            onPreview: (_) {},
            canDrag: false,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar ayuda de gesto'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('document representation fits at 320dp and text200', (
    tester,
  ) async {
    final c = AppController()
      ..starting = false
      ..selectedName = 'Reporte de campo.pdf';
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: AndroidFilePreview(
            controller: c,
            onBack: () {},
            onSend: () {},
            onDestination: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('returning from system settings refreshes denied photo access', (
    tester,
  ) async {
    final service = _PhotosAfterSettings();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: TeraxTheme.build(TeraxPlatform.android),
        home: Scaffold(
          body: LibraryBrowser(
            service: service,
            onPreview: (_) {},
            canDrag: false,
          ),
        ),
      ),
    );
    expect(find.text('Permitir acceso a fotos'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.refreshes, 1);
    expect(find.text('Todavía no hay fotos'), findsOneWidget);
  });
  testWidgets(
    'unreadable thumbnail keeps its status in screen reader semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: TeraxTheme.build(TeraxPlatform.android),
            home: Scaffold(
              body: SizedBox(
                width: 100,
                height: 120,
                child: TeraxLibraryTile(
                  name: 'foto.jpg',
                  state: TeraxTileState.unreadable,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.bySemanticsLabel(RegExp('No se puede leer')), findsWidgets);
      } finally {
        handle.dispose();
      }
    },
  );
}

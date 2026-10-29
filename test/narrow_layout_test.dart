import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/main.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/library/library_service.dart';

class _ConnectedDisplay extends AppController {
  @override
  PairingInfo get ownPairing => PairingInfo(
    host: '192.168.1.2',
    port: 4040,
    token: 'a' * 64,
    fingerprint: 'b' * 64,
    name: 'PC de prueba',
  );
}

void main() {
  testWidgets('QR panel fits 320px viewport and large text', (tester) async {
    final controller = _ConnectedDisplay()..starting = false;
    final library = LibraryService();
    addTearDown(library.dispose);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: teraxTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Home(controller: controller, library: library),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Copiar código'), findsNothing);
    await tester.tap(find.byTooltip('Abrir navegación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipos y ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Copiar código'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

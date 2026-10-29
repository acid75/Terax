import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/ui/settings.dart';
import 'package:terax/theme/terax_theme.dart';

class SettingsController extends AppController {
  @override
  PairingInfo? get ownPairing => const PairingInfo(
    host: '192.168.1.2',
    port: 443,
    token: 'test-token',
    fingerprint:
        '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
    name: 'Mi PC',
  );
}

void main() {
  testWidgets(
    'settings QR fits 320px and connection controls disable while starting',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTeraxSettings(context, controller),
                child: const Text('Settings'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Tus equipos'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Vincular otro equipo'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -550));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

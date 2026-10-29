import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/transfer/trust.dart';
import 'package:terax/ui/connection_glow.dart';
import 'package:terax/ui/transfer_flight.dart';
import 'package:terax/ui/transfer_scene.dart';
import 'package:terax/theme/terax_theme.dart';

class _Store implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _Client extends TransferClient {
  @override
  Future<String> probe(PairingInfo peer) async => 'PC';
}

class _Controller extends AppController {
  _Controller() : super(vault: DeviceVault(_Store()), client: _Client());
  int desktopCalls = 0;
  @override
  Future<bool> showDesktopWave({bool force = false}) async {
    desktopCalls++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'connecting does not invoke the desktop wave or fabricate a file transfer',
    () async {
      final c = _Controller();
      addTearDown(c.dispose);
      final p = PairingInfo(
        host: '192.168.1.2',
        port: 4040,
        token: 'a' * 64,
        fingerprint: 'b' * 64,
        name: 'PC',
      );
      expect(await c.connect(p.encode()), isTrue);

      expect(c.desktopCalls, 0);
      expect(c.outgoingId, isNull);
      expect(c.incomingVisual, isNull);
      expect(c.state, SendState.idle);
      await c.connect(p.encode());

      expect(c.desktopCalls, 0);
      c.disconnect();
      await c.connect(p.encode());
    },
  );
  for (final platform in TeraxPlatform.values) {
    testWidgets(
      'ambient glow breathes while connected without file or desktop animation on $platform',
      (tester) async {
        int taps = 0;
        Widget app(bool connected, {bool reduced = false}) => MaterialApp(
          theme: TeraxTheme.build(platform),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: ConnectionGlow(
              connected: connected,
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Archivo'),
              ),
            ),
          ),
        );
        await tester.pumpWidget(app(false));
        expect(find.byKey(const ValueKey('connection-glow')), findsNothing);
        await tester.pumpWidget(app(true));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('connection-glow')), findsOneWidget);
        expect(find.byType(TransferScene), findsNothing);
        expect(find.byType(TransferFlight), findsNothing);
        await tester.tap(find.text('Archivo'));
        expect(taps, 1);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('connection-glow')), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('connection-glow')), findsOneWidget);
        await tester.pumpWidget(app(true, reduced: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(false));
        expect(find.byKey(const ValueKey('connection-glow')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

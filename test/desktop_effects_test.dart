import 'dart:io';
import 'package:terax/transfer/transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/desktop_effects.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/transfer/trust.dart';

class _Store implements SecretStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('terax/files');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'desktopWave' ? true : null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'native overlay receives accessibility choice and stops explicitly',
    () async {
      expect(await const DesktopEffects().play(reducedMotion: true), isTrue);
      await const DesktopEffects().stop();
      expect(calls.map((c) => c.method), ['desktopWave', 'stopDesktopWave']);
      expect(calls.first.arguments, {'reducedMotion': true});
    },
  );
  test('overlay setup errors remain observable to the controller', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'desktop_effect',
            message: 'GPU unavailable',
          ),
        );
    expect(
      () => const DesktopEffects().play(reducedMotion: false),
      throwsA(isA<PlatformException>()),
    );
  });
  test(
    'real offer presents the receipt without covering it with a desktop snapshot',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'terax-receipt-scene-',
      );
      final c = AppController(
        vault: DeviceVault(_Store()),
        documentsDirectory: () async => folder,
      );
      try {
        await c.initialize();
        calls.clear();
        c.server!.onOffered!(
          TransferOffer(id: 'a' * 32, name: 'Informe.pdf', size: 100),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(calls.where((call) => call.method == 'desktopWave'), isEmpty);
        expect(
          calls.where((call) => call.method == 'presentIncoming'),
          isNotEmpty,
        );
        expect(c.incomingAnimationReady, isTrue);
      } finally {
        await c.server?.close();
        c.dispose();
        await Future<void>.delayed(Duration.zero);
        await folder.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
  test('desktop effect opt out survives reopening the vault', () async {
    final store = _Store();
    expect(await DeviceVault(store).desktopEffects(), isTrue);
    await DeviceVault(store).saveDesktopEffects(false);
    expect(await DeviceVault(store).desktopEffects(), isFalse);
  });
  testWidgets('system reduced motion skips the native screenshot effect', (
    tester,
  ) async {
    final c = AppController();
    addTearDown(c.dispose);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    expect(await c.showDesktopWave(force: true), false);
    expect(calls, isEmpty);
  });
}

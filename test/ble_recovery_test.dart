import 'dart:async';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/proximity.dart';

class FakeCentral implements CentralManager {
  final states =
      StreamController<BluetoothLowEnergyStateChangedEventArgs>.broadcast();
  final discoveries = StreamController<DiscoveredEventArgs>.broadcast();
  @override
  BluetoothLowEnergyState state = BluetoothLowEnergyState.unauthorized;
  bool granted = true;
  int scans = 0, prompts = 0;
  Object? scanError;
  @override
  Stream<BluetoothLowEnergyStateChangedEventArgs> get stateChanged =>
      states.stream;
  @override
  Stream<DiscoveredEventArgs> get discovered => discoveries.stream;
  @override
  Future<bool> authorize() async {
    prompts++;
    return granted;
  }

  @override
  Future<void> startDiscovery({List<UUID>? serviceUUIDs}) async {
    scans++;
    if (scanError != null) throw scanError!;
  }

  @override
  Future<void> stopDiscovery() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fingerprint =
      '00112233445566778899aabbccddeeff0123456789abcdef0123456789abcdef';
  test(
    'granted Android permission starts scan despite stale plugin state',
    () async {
      final central = FakeCentral();
      final statuses = <String>[];
      final proximity = BleProximity(
        fingerprint: fingerprint,
        trusted: () => [fingerprint],
        onStatus: statuses.add,
        onNearby: (_) {},
        central: central,
        platform: TargetPlatform.android,
      );
      await proximity.start(requestPermission: true);
      expect(central.prompts, 1);
      expect(central.scans, 1);
      expect(statuses.last, contains('Buscando'));
      await proximity.close();
    },
  );
  test('denied permission gives actionable status and never scans', () async {
    final central = FakeCentral()..granted = false;
    final statuses = <String>[];
    final proximity = BleProximity(
      fingerprint: fingerprint,
      trusted: () => [fingerprint],
      onStatus: statuses.add,
      onNearby: (_) {},
      central: central,
      platform: TargetPlatform.android,
    );
    await proximity.start(requestPermission: true);
    expect(central.scans, 0);
    expect(statuses.last, contains('Ajustes'));
    central.granted = true;
    await proximity.start(requestPermission: true);
    expect(central.prompts, 2);
    expect(central.scans, 1);
    expect(proximity.ready, isTrue);
    await proximity.close();
  });
  test(
    'native scan failure retains actionable diagnostic and can retry',
    () async {
      final central = FakeCentral()
        ..scanError = PlatformException(
          code: 'scan-failed',
          message: 'Bluetooth is off',
        );
      final statuses = <String>[];
      final proximity = BleProximity(
        fingerprint: fingerprint,
        trusted: () => [fingerprint],
        onStatus: statuses.add,
        onNearby: (_) {},
        central: central,
        platform: TargetPlatform.android,
      );
      await proximity.start(requestPermission: true);
      expect(proximity.ready, isFalse);
      expect(statuses.last, contains('scan-failed'));
      central.scanError = null;
      await proximity.start(requestPermission: true);
      expect(proximity.ready, isTrue);
      await proximity.close();
    },
  );
  testWidgets('Windows aborted publisher retries and can recover', (
    tester,
  ) async {
    var starts = 0;
    var now = DateTime(2026);
    const channel = MethodChannel('terax/proximity');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'start') {
        starts++;
        return starts == 1 ? 'aborted (BluetoothError=1)' : 'ready';
      }
      if (call.method == 'status') {
        return starts == 1 ? 'aborted (BluetoothError=1)' : 'ready';
      }
      return null;
    });
    final statuses = <String>[];
    final proximity = BleProximity(
      fingerprint: fingerprint,
      trusted: () => [],
      onStatus: statuses.add,
      onNearby: (_) {},
      platform: TargetPlatform.windows,
      now: () => now,
    );
    await proximity.start();
    expect(statuses.last, contains('radio'));
    now = now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(starts, 2);
    expect(statuses.last, 'Visible por Bluetooth');
    await proximity.close();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });
}

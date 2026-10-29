import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/transfer/trust.dart';

class _Secrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedClient extends TransferClient {
  final result = Completer<String>();
  final started = Completer<void>();
  @override
  Future<String> probe(PairingInfo peer) {
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'resetting links ignores a successful probe from the previous identity',
    () async {
      final folder = await Directory.systemTemp.createTemp('terax-reconnect-');
      final vault = DeviceVault(_Secrets());
      await vault.savePeers([
        PairingInfo(
          host: '127.0.0.1',
          port: 4040,
          token: 'a' * 64,
          fingerprint: 'b' * 64,
          name: 'PC olvidada',
        ),
      ]);
      final client = _DelayedClient();
      final controller = AppController(
        vault: vault,
        client: client,
        documentsDirectory: () async => folder,
      );
      try {
        await controller.initialize();
        await client.started.future.timeout(const Duration(seconds: 5));
        await controller.resetLinks();
        client.result.complete('PC olvidada');
        await Future<void>.delayed(Duration.zero);
        expect(controller.peer, isNull);
        expect(controller.peerOnline, isFalse);
        expect(controller.knownPeers, isEmpty);
      } finally {
        controller.dispose();
        await Future<void>.delayed(Duration.zero);
        await folder.delete(recursive: true);
      }
    },
  );
}

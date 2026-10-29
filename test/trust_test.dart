import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/trust.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/discovery.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test(
    'identity and trusted peer survive a new application instance',
    () async {
      final secrets = MemorySecrets();
      final first = DeviceVault(secrets);
      final identity = await first.loadIdentity();
      final peer = PairingInfo(
        host: '192.168.1.2',
        port: 4040,
        token: 'a' * 64,
        fingerprint: 'b' * 64,
        name: 'Mi PC',
      );
      await first.savePeers([peer]);
      final second = DeviceVault(secrets);
      final restored = await second.loadIdentity();
      expect(restored.identity.fingerprint, identity.identity.fingerprint);
      expect(restored.token, identity.token);
      expect((await second.loadPeers()).single.token, peer.token);
      await second.resetLinks();
      final reset = await second.loadIdentity();
      expect(reset.token, isNot(identity.token));
      expect(reset.identity.fingerprint, isNot(identity.identity.fingerprint));
      expect(await second.loadPeers(), isEmpty);
    },
  );

  test(
    'discovery proof rejects unknown secrets, changed port and replay nonce',
    () {
      final target = PairingInfo(
        host: '192.168.1.2',
        port: 4040,
        token: 'a' * 64,
        fingerprint: 'b' * 64,
        name: 'Mi PC',
      );
      final reply = DiscoveryProof.reply(target, 'c' * 32);
      expect(DiscoveryProof.verifyReply(reply, target, 'c' * 32), isTrue);
      expect(
        DiscoveryProof.verifyReply(
          reply,
          target.copyWith(token: 'd' * 64),
          'c' * 32,
        ),
        isFalse,
      );
      expect(
        DiscoveryProof.verifyReply({...reply, 'port': 9999}, target, 'c' * 32),
        isFalse,
      );
      expect(DiscoveryProof.verifyReply(reply, target, 'e' * 32), isFalse);
      expect(reply.toString(), isNot(contains(target.token)));
    },
  );
}

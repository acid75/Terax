import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'identity.dart';
import 'protocol.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PlatformSecrets implements SecretStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class DeviceIdentity {
  const DeviceIdentity(this.identity, this.token);
  final ServerIdentity identity;
  final String token;
}

class DeviceVault {
  DeviceVault(this.store);
  final SecretStore store;

  Future<DeviceIdentity> loadIdentity() async {
    final saved = await store.read('terax.identity.v1');
    if (saved != null) {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      return DeviceIdentity(
        ServerIdentity(
          data['certificate'] as String,
          data['key'] as String,
          data['fingerprint'] as String,
        ),
        data['token'] as String,
      );
    }
    final identity = await ServerIdentity.generate();
    final token = randomHex();
    await store.write(
      'terax.identity.v1',
      jsonEncode({
        'certificate': identity.certificate,
        'key': identity.privateKey,
        'fingerprint': identity.fingerprint,
        'token': token,
      }),
    );
    return DeviceIdentity(identity, token);
  }

  Future<List<PairingInfo>> loadPeers() async {
    final saved = await store.read('terax.peers.v1');
    if (saved == null) return [];
    return (jsonDecode(saved) as List<dynamic>)
        .map((code) => PairingInfo.parse(code as String))
        .toList();
  }

  Future<void> savePeers(List<PairingInfo> peers) => store.write(
    'terax.peers.v1',
    jsonEncode(peers.map((p) => p.encode()).toList()),
  );
  Future<bool> autoOpen() async =>
      await store.read('terax.autoOpen.v1') == 'true';
  Future<void> saveAutoOpen(bool value) =>
      store.write('terax.autoOpen.v1', '$value');
  Future<bool> proximityEnabled() async =>
      await store.read('terax.proximity.v1') == 'true';
  Future<void> saveProximity(bool value) =>
      store.write('terax.proximity.v1', '$value');
  Future<bool> desktopEffects() async =>
      await store.read('terax.desktopEffects.v1') != 'false';
  Future<void> saveDesktopEffects(bool value) =>
      store.write('terax.desktopEffects.v1', '$value');

  Future<void> resetLinks() async {
    final identity = await ServerIdentity.generate();
    await store.write(
      'terax.identity.v1',
      jsonEncode({
        'certificate': identity.certificate,
        'key': identity.privateKey,
        'fingerprint': identity.fingerprint,
        'token': randomHex(),
      }),
    );
    await savePeers([]);
  }
}

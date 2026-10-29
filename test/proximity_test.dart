import 'dart:typed_data';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/proximity.dart';

void main() {
  const fingerprint =
      '00112233445566778899aabbccddeeff0123456789abcdef0123456789abcdef';
  final bytes = Uint8List.fromList([
    0x54,
    0x52,
    0x58,
    2,
    ...List.generate(16, (i) => i * 17),
  ]);
  test('manufacturer beacon resolves only a trusted full fingerprint', () {
    final advertisement = Advertisement(
      manufacturerSpecificData: [
        ManufacturerSpecificData(id: 0xffff, data: bytes),
      ],
    );
    expect(trustedBeaconFingerprint(advertisement, [fingerprint]), fingerprint);
    expect(trustedBeaconFingerprint(advertisement, []), isNull);
  });
  test('rejects foreign company, unsupported version and malformed length', () {
    for (final entry in [
      ManufacturerSpecificData(id: 1, data: bytes),
      ManufacturerSpecificData(
        id: 0xffff,
        data: Uint8List.fromList([...bytes]..[3] = 1),
      ),
      ManufacturerSpecificData(
        id: 0xffff,
        data: Uint8List.fromList(bytes.take(19).toList()),
      ),
    ]) {
      expect(
        trustedBeaconFingerprint(
          Advertisement(manufacturerSpecificData: [entry]),
          [fingerprint],
        ),
        isNull,
      );
    }
  });
  test('service UUID alone cannot impersonate a manufacturer beacon', () {
    expect(
      trustedBeaconFingerprint(
        Advertisement(
          serviceUUIDs: [
            UUID.fromString('00112233-4455-6677-8899-aabbccddeeff'),
          ],
        ),
        [fingerprint],
      ),
      isNull,
    );
  });
  test('ambiguous fingerprint prefixes cannot select a peer', () {
    expect(
      trustedBeaconFingerprint(
        Advertisement(
          manufacturerSpecificData: [
            ManufacturerSpecificData(id: 0xffff, data: bytes),
          ],
        ),
        [fingerprint, '${fingerprint.substring(0, 32)}${'f' * 32}'],
      ),
      isNull,
    );
  });
  test('a truncated trust identity cannot select a peer', () {
    expect(
      trustedBeaconFingerprint(
        Advertisement(
          manufacturerSpecificData: [
            ManufacturerSpecificData(id: 0xffff, data: bytes),
          ],
        ),
        [fingerprint.substring(0, 32)],
      ),
      isNull,
    );
  });
  test('isolated strong signal does not mark near; stable approach does', () {
    final signal = ProximityFilter();
    expect(signal.update(-45), isFalse);
    expect(signal.update(-44), isFalse);
    expect(signal.update(-43), isTrue);
    expect(signal.update(-60), isTrue);
    for (var i = 0; i < 20; i++) {
      signal.update(-85);
    }
    expect(signal.near, isFalse);
  });
}

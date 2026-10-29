import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/discovery.dart';
import 'package:terax/transfer/protocol.dart';

void main() {
  test(
    'real UDP discovery advertises the current endpoint without exposing token',
    () async {
      final saved = PairingInfo(
        host: '127.0.0.1',
        port: 4040,
        token: 'a' * 64,
        fingerprint: 'b' * 64,
        name: 'Mi PC',
      );
      final live = saved.copyWith(port: 5050);
      final service = LanDiscovery(
        own: () => live,
        peers: () => [],
        onFound: (_) {},
      );
      await service.start(port: 0);
      final client = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final answer = Completer<Map<String, dynamic>>();
      final listener = client.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = client.receive();
        if (datagram != null && !answer.isCompleted) {
          answer.complete(
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>,
          );
        }
      });
      try {
        final nonce = 'c' * 32;
        client.send(
          utf8.encode(jsonEncode(DiscoveryProof.query(saved, nonce))),
          InternetAddress.loopbackIPv4,
          service.boundPort!,
        );
        final reply = await answer.future.timeout(const Duration(seconds: 5));
        expect(reply['port'], 5050);
        expect(DiscoveryProof.verifyReply(reply, saved, nonce), isTrue);
        expect(jsonEncode(reply), isNot(contains(saved.token)));
      } finally {
        await listener.cancel();
        client.close();
        await service.close();
      }
    },
  );
}

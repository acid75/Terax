import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/identity.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';

void main() {
  late Directory folder;
  late TransferServer server;
  late PairingInfo peer;
  final events = <String>[];
  Completer<void>? expired;
  String? nearDevice;
  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('terax-offer-');
    server = TransferServer(
      directory: folder,
      identity: await ServerIdentity.generate(),
      name: 'PC',
      offerTimeout: const Duration(milliseconds: 250),
      onOffered: (_) => events.add('receiver-ready'),
      onProximity: (device, near) {
        nearDevice = near ? device : null;
      },
      onProgress: (event) {
        if (event != null && event.bytes > 0) events.add('bytes');
        if (event == null && expired != null && !expired!.isCompleted) {
          expired!.complete();
        }
      },
    );
    await server.start(address: InternetAddress.loopbackIPv4);
    peer = server.pairingFor('127.0.0.1');
  });
  tearDownAll(() async {
    await server.close();
    await folder.delete(recursive: true);
  });

  test(
    'receiver and sender start before file bytes, using the same offer id',
    () async {
      events.clear();
      final source = await File(
        '${folder.path}/source.txt',
      ).writeAsString('hola');
      await TransferClient().send(
        source,
        peer,
        onReady: (offer) => events.add('sender-ready'),
      );
      expect(
        events.indexOf('receiver-ready'),
        lessThan(events.indexOf('sender-ready')),
      );
      expect(events.indexOf('sender-ready'), lessThan(events.indexOf('bytes')));
    },
  );

  test(
    'offer reserves receiver until cancelled, then another file can start',
    () async {
      final client = TransferClient();
      final first = TransferOffer(id: 'a' * 32, name: 'uno.pdf', size: 10);
      final second = TransferOffer(id: 'b' * 32, name: 'dos.pdf', size: 20);
      await client.offer(peer, first);
      await expectLater(
        client.offer(peer, second),
        throwsA(isA<TransferException>()),
      );
      await client.cancelOffer(peer, first.id);
      await client.offer(peer, second);
      await client.cancelOffer(peer, second.id);
      expect(
        await folder.list().where((e) => e.path.endsWith('.part')).length,
        0,
      );
    },
  );

  test('abandoned offer expires and releases the receiving slot', () async {
    expired = Completer<void>();
    final client = TransferClient();
    await client.offer(
      peer,
      TransferOffer(id: 'c' * 32, name: 'abandono.txt', size: 1),
    );
    await expired!.future.timeout(const Duration(seconds: 3));
    expired = null;
    await client.offer(
      peer,
      TransferOffer(id: 'd' * 32, name: 'nuevo.txt', size: 1),
    );
    await client.cancelOffer(peer, 'd' * 32);
  });

  test(
    'authenticated phone proximity notifies the PC before any file is offered',
    () async {
      final client = TransferClient();
      await client.nearby(peer, 'e' * 64, true);
      expect(nearDevice, 'e' * 64);
      await client.nearby(peer, 'e' * 64, false);
      expect(nearDevice, isNull);
      await expectLater(
        client.nearby(peer.copyWith(token: 'f' * 64), 'e' * 64, true),
        throwsA(isA<TransferException>()),
      );
      expect(nearDevice, isNull);
    },
  );
}

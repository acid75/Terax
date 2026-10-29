import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/identity.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';

void main() {
  test('pairing rejects public hosts and malformed credentials', () {
    expect(
      () => PairingInfo.parse('https://example.com'),
      throwsFormatException,
    );
    final peer = PairingInfo(
      host: '127.0.0.1',
      port: 4040,
      token: 'a' * 64,
      fingerprint: 'b' * 64,
      name: 'Mi PC',
    );
    expect(PairingInfo.parse(peer.encode()).name, 'Mi PC');
    expect(
      () => PairingInfo.parse(peer.copyWith(host: '8.8.8.8').encode()),
      throwsFormatException,
    );
  });

  test('incoming names cannot traverse directories or use reserved names', () {
    expect(safeFileName('../../foto.png'), 'foto.png');
    expect(safeFileName(r'C:\Users\foto.png'), 'foto.png');
    expect(safeFileName('CON.exe'), 'archivo_CON.exe');
    expect(safeFileName('...'), 'archivo');
  });

  late Directory temp;
  late TransferServer server;
  late PairingInfo peer;
  late File source;
  late List<ReceivedFile> received;
  PairingInfo? paired;
  Completer<void>? receiving;
  Completer<void>? released;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('terax-test-');
    final identity = await ServerIdentity.generate();
    received = [];
    server = TransferServer(
      directory: Directory('${temp.path}/inbox'),
      identity: identity,
      name: 'PC de prueba',
      maxBytes: 1024,
      onReceived: received.add,
      onPaired: (remote) async {
        paired = remote;
      },
      onProgress: (event) {
        if (event != null &&
            event.bytes > 0 &&
            receiving != null &&
            !receiving!.isCompleted) {
          receiving!.complete();
        }
        if (event == null && released != null && !released!.isCompleted) {
          released!.complete();
        }
      },
    );
    await server.start(address: InternetAddress.loopbackIPv4);
    peer = server.pairingFor('127.0.0.1');
    source = await File('${temp.path}/imagen.png').writeAsBytes([1, 2, 3, 4]);
  });
  tearDownAll(() async {
    await server.close();
    await temp.delete(recursive: true);
  });

  test(
    'real pinned HTTPS streams bytes and preserves colliding filenames',
    () async {
      expect(await TransferClient().probe(peer), 'PC de prueba');
      final progress = <double>[];
      await TransferClient().send(source, peer, onProgress: progress.add);
      await TransferClient().send(source, peer);
      expect(received.length, 2);
      expect(await received.first.file.readAsBytes(), [1, 2, 3, 4]);
      expect(received.first.file.path, isNot(received.last.file.path));
      expect(progress.last, 1);
    },
  );

  test('wrong session token and certificate pin cannot upload', () async {
    final before = received.length;
    await expectLater(
      TransferClient().send(source, peer.copyWith(token: 'c' * 64)),
      throwsA(isA<TransferException>()),
    );
    await expectLater(
      TransferClient().probe(peer.copyWith(fingerprint: 'd' * 64)),
      throwsA(anything),
    );
    expect(received.length, before);
  });

  test(
    'first authorization exchanges return address over authenticated TLS',
    () async {
      final returning = PairingInfo(
        host: '192.168.99.99',
        port: 44662,
        token: 'e' * 64,
        fingerprint: 'f' * 64,
        name: 'Mi Android',
      );
      await TransferClient().pair(peer, returning);
      expect(paired!.host, '127.0.0.1');
      expect(paired!.token, returning.token);
      expect(paired!.fingerprint, returning.fingerprint);
      expect(paired!.name, 'Mi Android');
      paired = null;
      await expectLater(
        TransferClient().pair(peer.copyWith(token: 'd' * 64), returning),
        throwsA(isA<TransferException>()),
      );
      expect(paired, isNull);
    },
  );

  Future<int> rawUpload(List<int> bytes, String hash, {String? name}) async {
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..badCertificateCallback = (cert, host, port) =>
          sha256.convert(cert.der).toString() == peer.fingerprint;
    try {
      final req = await client.postUrl(
        Uri.https('${peer.host}:${peer.port}', '/v1/files'),
      );
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${peer.token}');
      req.headers.set(
        'x-terax-name',
        base64Url.encode(utf8.encode(name ?? '../imagen.png')),
      );
      req.headers.set('x-terax-sha256', hash);
      req.contentLength = bytes.length;
      req.add(bytes);
      final response = await req.close();
      await response.drain<void>();
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  test('hash mismatch and oversized files leave no partial files', () async {
    expect(await rawUpload([9, 8], '0' * 64), 422);
    final large = List<int>.filled(1025, 0);
    expect(await rawUpload(large, sha256.convert(large).toString()), 413);
    expect(
      await server.directory
          .list()
          .where((f) => f.path.endsWith('.part'))
          .length,
      0,
    );
    expect(await rawUpload([42], sha256.convert([42]).toString()), 201);
  });

  test('paused reception rejects otherwise authorized uploads', () async {
    server.accepting = false;
    expect(await rawUpload([1], sha256.convert([1]).toString()), 403);
    server.accepting = true;
  });

  test(
    'concurrent upload is rejected and disconnect cleans the partial file',
    () async {
      receiving = Completer<void>();
      released = Completer<void>();
      final before = received.length;
      final client =
          HttpClient(context: SecurityContext(withTrustedRoots: false))
            ..badCertificateCallback = (cert, host, port) =>
                sha256.convert(cert.der).toString() == peer.fingerprint;
      try {
        final req = await client.postUrl(
          Uri.https('${peer.host}:${peer.port}', '/v1/files'),
        );
        req.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${peer.token}',
        );
        req.headers.set(
          'x-terax-name',
          base64Url.encode(utf8.encode('interrumpido.png')),
        );
        req.headers.set('x-terax-sha256', sha256.convert([1, 2]).toString());
        req.contentLength = 2;
        req.bufferOutput = false;
        req.add([1]);
        await req.flush();
        await receiving!.future.timeout(const Duration(seconds: 5));
        expect(await rawUpload([3], sha256.convert([3]).toString()), 409);
        req.abort();
        await released!.future.timeout(const Duration(seconds: 5));
        expect(received.length, before);
        expect(
          await server.directory
              .list()
              .where((f) => f.path.endsWith('.part'))
              .length,
          0,
        );
        expect(await rawUpload([4], sha256.convert([4]).toString()), 201);
      } finally {
        client.close(force: true);
        receiving = null;
        released = null;
      }
    },
  );

  test('empty files complete without invalid progress', () async {
    final empty = await File('${temp.path}/vacio.txt').writeAsBytes([]);
    final progress = <double>[];
    await TransferClient().send(empty, peer, onProgress: progress.add);
    expect(await received.last.file.length(), 0);
    expect(progress.last, 1);
    expect(progress.every((p) => p.isFinite && p >= 0 && p <= 1), isTrue);
  });

  test(
    'cancelling integrity calculation stops consuming source chunks',
    () async {
      var cancelled = false;
      var consumed = 0;
      Stream<List<int>> chunks() async* {
        consumed++;
        yield [1];
        cancelled = true;
        consumed++;
        yield [2];
        consumed++;
        yield [3];
      }

      await expectLater(
        hashForTransfer(chunks(), cancelled: () => cancelled),
        throwsA(isA<TransferException>()),
      );
      expect(consumed, 2);
    },
  );
}

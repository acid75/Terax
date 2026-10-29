import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'identity.dart';
import 'protocol.dart';

typedef ProgressCallback = void Function(double progress);

/// Hashes a streaming source, stopping file reads as soon as sending is cancelled.
Future<Digest> hashForTransfer(
  Stream<List<int>> source, {
  required bool Function() cancelled,
}) => sha256
    .bind(
      source.map((chunk) {
        if (cancelled()) throw const TransferException('Envío cancelado.');
        return chunk;
      }),
    )
    .first;

class ReceivedFile {
  const ReceivedFile(this.file, this.name, this.size, {this.id});
  final File file;
  final String name;
  final int size;
  final String? id;
}

class TransferOffer {
  const TransferOffer({
    required this.id,
    required this.name,
    required this.size,
    this.preview,
  });
  final String id, name;
  final int size;
  final String? preview;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    if (preview != null) 'preview': preview,
  };
  static TransferOffer parse(Map<String, dynamic> data) {
    final id = data['id'];
    final name = data['name'];
    final size = data['size'];
    if (id is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
        name is! String ||
        name.isEmpty ||
        name.length > 512 ||
        size is! int ||
        size < 0 ||
        size > maxFileBytes) {
      throw const TransferException('Oferta de archivo inválida.');
    }
    final preview = data['preview'];
    if (preview != null &&
        (preview is! String ||
            preview.length > 32768 ||
            base64.decode(preview).length > 24576)) {
      throw const TransferException('Vista previa demasiado grande.');
    }
    return TransferOffer(
      id: id,
      name: safeFileName(name),
      size: size,
      preview: preview as String?,
    );
  }
}

enum IncomingStage { preparing, receiving, verifying }

class IncomingProgress {
  const IncomingProgress(
    this.name,
    this.bytes,
    this.total, {
    this.id,
    this.stage = IncomingStage.receiving,
  });
  final String name;
  final int bytes, total;
  final String? id;
  final IncomingStage stage;
}

class TransferServer {
  TransferServer({
    required this.directory,
    required this.identity,
    required this.name,
    this.maxBytes = maxFileBytes,
    this.onReceived,
    this.onProgress,
    this.onError,
    this.onPaired,
    this.onOffered,
    this.onProximity,
    this.offerTimeout = const Duration(minutes: 2),
    String? token,
  }) : _token = token ?? randomHex();
  final Directory directory;
  final ServerIdentity identity;
  final String name;
  final int maxBytes;
  final void Function(ReceivedFile)? onReceived;
  final void Function(IncomingProgress?)? onProgress;
  final void Function(String)? onError;
  final Future<void> Function(PairingInfo)? onPaired;
  final void Function(TransferOffer)? onOffered;
  final void Function(String fingerprint, bool near)? onProximity;
  final Duration offerTimeout;
  final String _token;
  HttpServer? _server;
  bool accepting = true;
  bool _busy = false;
  TransferOffer? _offered;
  Timer? _offerExpiry;

  void _clearOffer() {
    _offerExpiry?.cancel();
    _offered = null;
    if (!_busy) onProgress?.call(null);
  }

  Future<Map<String, dynamic>> _smallBody(
    HttpRequest request, {
    int limit = 4096,
  }) async {
    final bytes = <int>[];
    await for (final chunk in request.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length > limit) {
        throw const TransferException('Solicitud demasiado grande.');
      }
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  PairingInfo pairingFor(String host) => PairingInfo(
    host: host,
    port: _server!.port,
    token: _token,
    fingerprint: identity.fingerprint,
    name: name,
  );

  Future<void> start({InternetAddress? address, int port = 0}) async {
    await directory.create(recursive: true);
    _server = await HttpServer.bindSecure(
      address ?? InternetAddress.anyIPv4,
      port,
      identity.context(),
    );
    _server!.idleTimeout = const Duration(seconds: 30);
    _server!.listen((request) => unawaited(_handle(request)));
  }

  Future<void> _reply(HttpRequest request, int status, String message) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'message': message}));
    await request.response.close();
  }

  Future<void> _handle(HttpRequest request) async {
    File? partial;
    IOSink? sink;
    var ownsSlot = false;
    try {
      if (!secureEquals(
        request.headers.value(HttpHeaders.authorizationHeader) ?? '',
        'Bearer $_token',
      )) {
        await _reply(
          request,
          401,
          'El código caducó. Vuelve a conectar el equipo.',
        );
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/info') {
        await _reply(request, 200, this.name);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/proximity') {
        final body = await _smallBody(request);
        final fingerprint = body['device'];
        final near = body['near'];
        if (fingerprint is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint) ||
            near is! bool) {
          await _reply(request, 400, 'Señal de cercanía inválida.');
          return;
        }
        onProximity?.call(fingerprint, near);
        await _reply(request, 200, 'Señal recibida.');
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/offer') {
        if (!accepting) {
          await _reply(request, 403, 'La recepción está pausada.');
          return;
        }
        if (_busy || _offered != null) {
          await _reply(
            request,
            409,
            'El otro equipo ya está recibiendo un archivo.',
          );
          return;
        }
        final offer = TransferOffer.parse(
          await _smallBody(request, limit: 49152),
        );
        if (offer.size > maxBytes) {
          await _reply(request, 413, 'Archivo demasiado grande.');
          return;
        }
        // Recheck after reading the asynchronous body: another offer may have won.
        if (_busy || _offered != null) {
          await _reply(
            request,
            409,
            'El otro equipo ya está recibiendo un archivo.',
          );
          return;
        }
        _offered = offer;
        _offerExpiry = Timer(offerTimeout, () {
          if (!_busy && _offered?.id == offer.id) _clearOffer();
        });
        onOffered?.call(offer);
        onProgress?.call(
          IncomingProgress(
            offer.name,
            0,
            offer.size,
            id: offer.id,
            stage: IncomingStage.preparing,
          ),
        );
        await _reply(request, 201, 'Listo para recibir.');
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/cancel') {
        final data = await _smallBody(request);
        if (!_busy && data['id'] == _offered?.id) _clearOffer();
        await _reply(request, 200, 'Oferta cancelada.');
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/pair') {
        if (!accepting) {
          await _reply(request, 403, 'La recepción está pausada.');
          return;
        }
        final bytes = <int>[];
        await for (final chunk in request.timeout(
          const Duration(seconds: 10),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 4096) {
            throw const TransferException('Código demasiado grande.');
          }
        }
        final remote = PairingInfo.parse(utf8.decode(bytes));
        final host = request.connectionInfo?.remoteAddress.address;
        if (host == null || !isLocalAddress(host)) {
          throw const TransferException(
            'El equipo debe estar en tu red local.',
          );
        }
        await onPaired?.call(remote.copyWith(host: host));
        await _reply(
          request,
          201,
          'Equipo autorizado. No necesitas volver a escanear.',
        );
        return;
      }
      if (request.method != 'POST' || request.uri.path != '/v1/files') {
        await _reply(request, 404, 'Ruta desconocida');
        return;
      }
      if (!accepting) {
        await _reply(
          request,
          403,
          'El otro equipo tiene la recepción pausada.',
        );
        return;
      }
      if (_busy) {
        await _reply(
          request,
          409,
          'El otro equipo ya está recibiendo un archivo.',
        );
        return;
      }
      final transferId = request.headers.value('x-terax-transfer');
      if (_offered != null && transferId != _offered!.id) {
        await _reply(
          request,
          409,
          'El receptor está reservado para otro envío.',
        );
        return;
      }
      final size = request.contentLength;
      if (size < 0 || size > maxBytes) {
        await _reply(request, 413, 'Archivo demasiado grande (máximo 1 GiB).');
        return;
      }
      final rawName = request.headers.value('x-terax-name') ?? '';
      final expected = request.headers.value('x-terax-sha256') ?? '';
      if (rawName.length > 2048 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(expected)) {
        await _reply(request, 400, 'Metadatos de archivo inválidos.');
        return;
      }
      final name = safeFileName(utf8.decode(base64Url.decode(rawName)));
      if (_offered != null &&
          (_offered!.size != size || _offered!.name != name)) {
        await _reply(request, 400, 'El archivo no corresponde a la oferta.');
        return;
      }
      _busy = true;
      _offerExpiry?.cancel();
      ownsSlot = true;
      final id = randomHex(16);
      partial = File(p.join(directory.path, '$id.part'));
      sink = partial.openWrite();
      final digest = _DigestSink();
      final hash = sha256.startChunkedConversion(digest);
      var count = 0;
      onProgress?.call(IncomingProgress(name, 0, size, id: transferId));
      await for (final chunk in request.timeout(const Duration(seconds: 30))) {
        count += chunk.length;
        if (count > size || count > maxBytes) {
          throw const TransferException('Tamaño recibido inválido.');
        }
        hash.add(chunk);
        sink.add(chunk);
        // Await writes to maintain bounded memory even on slow disks.
        await sink.flush();
        onProgress?.call(IncomingProgress(name, count, size, id: transferId));
      }
      hash.close();
      onProgress?.call(
        IncomingProgress(
          name,
          count,
          size,
          id: transferId,
          stage: IncomingStage.verifying,
        ),
      );
      await sink.close();
      sink = null;
      if (count != size || digest.value.toString() != expected) {
        await _reply(
          request,
          422,
          'El archivo no pasó la verificación de integridad.',
        );
        return;
      }
      final finalFile = await partial.rename(
        p.join(directory.path, '${id}_$name'),
      );
      partial = null;
      onReceived?.call(ReceivedFile(finalFile, name, count, id: transferId));
      await _reply(request, 201, 'Archivo recibido y verificado.');
    } catch (error) {
      onError?.call(
        error is TransferException
            ? error.message
            : 'Se interrumpió la recepción. Intenta de nuevo.',
      );
      try {
        await _reply(
          request,
          400,
          'La transferencia se interrumpió o no es válida.',
        );
      } catch (_) {
        /* Connection already closed. */
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        /* Best effort on failed disk writes. */
      }
      try {
        if (partial != null && await partial.exists()) {
          await partial.delete();
        }
      } on FileSystemException {
        onError?.call(
          'No se pudo borrar un archivo incompleto. Puedes eliminar los archivos .part en Recibidos.',
        );
      } finally {
        if (ownsSlot) {
          _busy = false;
          _clearOffer();
        }
      }
    }
  }

  Future<void> close() async {
    _offerExpiry?.cancel();
    await _server?.close(force: true);
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

class TransferClient {
  HttpClient? _active;
  bool _cancelled = false;

  HttpClient _client(PairingInfo peer) =>
      HttpClient(context: SecurityContext(withTrustedRoots: false))
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 30)
        ..badCertificateCallback = (certificate, host, port) =>
            host == peer.host &&
            port == peer.port &&
            secureEquals(
              sha256.convert(certificate.der).toString(),
              peer.fingerprint,
            );

  Future<HttpClientRequest> _request(
    HttpClient client,
    PairingInfo peer,
    String method,
    String route,
  ) async {
    final request = await client.openUrl(
      method,
      Uri.https('${peer.host}:${peer.port}', route),
    );
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${peer.token}',
    );
    return request;
  }

  Future<String> _read(HttpClientResponse response, int expected) async {
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      bytes.addAll(chunk);
      if (bytes.length > 8192) {
        throw const TransferException('Respuesta inesperada del equipo.');
      }
    }
    final message =
        (jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>)['message']
            as String;
    if (response.statusCode != expected) throw TransferException(message);
    return message;
  }

  Future<String> probe(PairingInfo peer) async {
    final client = _client(peer);
    try {
      final request = await _request(client, peer, 'GET', '/v1/info');
      return await _read(
        await request.close().timeout(const Duration(seconds: 15)),
        200,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> pair(PairingInfo peer, PairingInfo own) async {
    final client = _client(peer);
    try {
      final request = await _request(client, peer, 'POST', '/v1/pair');
      final bytes = utf8.encode(own.encode());
      request.contentLength = bytes.length;
      request.add(bytes);
      await _read(
        await request.close().timeout(const Duration(seconds: 15)),
        201,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _control(
    HttpClient client,
    PairingInfo peer,
    String route,
    Map<String, dynamic> body,
    int expected,
  ) async {
    final request = await _request(client, peer, 'POST', route);
    final bytes = utf8.encode(jsonEncode(body));
    request.contentLength = bytes.length;
    request.headers.contentType = ContentType.json;
    request.add(bytes);
    await _read(
      await request.close().timeout(const Duration(seconds: 12)),
      expected,
    );
  }

  Future<void> offer(PairingInfo peer, TransferOffer offer) async {
    final client = _client(peer);
    try {
      await _control(client, peer, '/v1/offer', offer.toJson(), 201);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> nearby(PairingInfo peer, String fingerprint, bool near) async {
    final client = _client(peer);
    try {
      await _control(client, peer, '/v1/proximity', {
        'device': fingerprint,
        'near': near,
      }, 200);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> cancelOffer(PairingInfo peer, String id) async {
    final client = _client(peer);
    try {
      await _control(client, peer, '/v1/cancel', {'id': id}, 200);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> send(
    File file,
    PairingInfo peer, {
    ProgressCallback? onProgress,
    void Function(TransferOffer)? onReady,
    String? name,
    String? preview,
  }) async {
    _cancelled = false;
    final client = _client(peer);
    _active = client;
    String? offeredId;
    var completed = false;
    try {
      final size = await file.length();
      if (size > maxFileBytes) {
        throw const TransferException('El máximo por archivo es 1 GiB.');
      }
      final offer = TransferOffer(
        id: randomHex(16),
        name: safeFileName(name ?? p.basename(file.path)),
        size: size,
        preview: preview,
      );
      offeredId = offer.id;
      await _control(client, peer, '/v1/offer', offer.toJson(), 201);
      if (_cancelled) throw const TransferException('Envío cancelado.');
      onReady?.call(offer);
      final hash = await hashForTransfer(
        file.openRead(),
        cancelled: () => _cancelled,
      );
      if (_cancelled) throw const TransferException('Envío cancelado.');
      final request = await _request(client, peer, 'POST', '/v1/files');
      request.contentLength = size;
      request.headers.contentType = ContentType.binary;
      request.headers.set(
        'x-terax-name',
        base64Url.encode(utf8.encode(offer.name)),
      );
      request.headers.set('x-terax-sha256', hash.toString());
      request.headers.set('x-terax-transfer', offer.id);
      var count = 0;
      final stream = file.openRead().map((chunk) {
        if (_cancelled) throw const TransferException('Envío cancelado.');
        count += chunk.length;
        onProgress?.call(size == 0 ? 0 : (count / size).clamp(0, .99));
        return chunk;
      });
      await request.addStream(stream).timeout(const Duration(minutes: 20));
      await _read(
        await request.close().timeout(const Duration(seconds: 45)),
        201,
      );
      onProgress?.call(1);
      completed = true;
    } finally {
      client.close(force: true);
      _active = null;
      if (!completed && offeredId != null) {
        unawaited(
          cancelOffer(
            peer,
            offeredId,
          ).timeout(const Duration(seconds: 2)).catchError((_) {}),
        );
      }
    }
  }

  void cancel() {
    _cancelled = true;
    _active?.close(force: true);
  }
}

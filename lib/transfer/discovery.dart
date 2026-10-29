import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'protocol.dart';

const discoveryPort = 44661;

/// Only known peers can request/verify an endpoint. No tokens are broadcast.
class DiscoveryProof {
  static String _mac(String token, String message) =>
      Hmac(sha256, utf8.encode(token)).convert(utf8.encode(message)).toString();
  static Map<String, dynamic> query(PairingInfo peer, String nonce) => {
    'v': 1,
    'type': 'query',
    'id': peer.fingerprint,
    'nonce': nonce,
    'mac': _mac(peer.token, 'query|${peer.fingerprint}|$nonce'),
  };
  static bool verifyQuery(Map<String, dynamic> packet, PairingInfo own) =>
      packet['v'] == 1 &&
      packet['type'] == 'query' &&
      packet['id'] == own.fingerprint &&
      packet['nonce'] is String &&
      RegExp(r'^[a-f0-9]{32}$').hasMatch(packet['nonce'] as String) &&
      secureEquals(
        packet['mac'] is String ? packet['mac'] as String : '',
        _mac(own.token, 'query|${own.fingerprint}|${packet['nonce']}'),
      );
  static Map<String, dynamic> reply(PairingInfo own, String nonce) => {
    'v': 1,
    'type': 'here',
    'id': own.fingerprint,
    'nonce': nonce,
    'port': own.port,
    'mac': _mac(own.token, 'here|${own.fingerprint}|$nonce|${own.port}'),
  };
  static bool verifyReply(
    Map<String, dynamic> packet,
    PairingInfo peer,
    String nonce,
  ) =>
      packet['v'] == 1 &&
      packet['type'] == 'here' &&
      packet['id'] == peer.fingerprint &&
      packet['nonce'] == nonce &&
      packet['port'] is int &&
      (packet['port'] as int) > 0 &&
      (packet['port'] as int) <= 65535 &&
      secureEquals(
        packet['mac'] is String ? packet['mac'] as String : '',
        _mac(peer.token, 'here|${peer.fingerprint}|$nonce|${packet['port']}'),
      );
}

class LanDiscovery {
  LanDiscovery({required this.own, required this.peers, required this.onFound});
  final PairingInfo Function() own;
  final List<PairingInfo> Function() peers;
  final void Function(PairingInfo) onFound;
  RawDatagramSocket? _socket;
  int? get boundPort => _socket?.port;
  Timer? _timer;
  StreamSubscription<RawSocketEvent>? _subscription;
  final _pending = <String, ({PairingInfo peer, DateTime time})>{};
  DateTime _lastReply = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start({int port = discoveryPort}) async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
    _socket!.broadcastEnabled = true;
    _subscription = _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? data;
      while ((data = _socket?.receive()) != null) {
        _receive(data!);
      }
    }, onError: (_) {});
    search();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => search());
  }

  void _send(Map<String, dynamic> packet, InternetAddress address, int port) {
    try {
      _socket?.send(utf8.encode(jsonEncode(packet)), address, port);
    } on SocketException {
      /* Try again on the next LAN tick. */
    }
  }

  void search() {
    final now = DateTime.now();
    _pending.removeWhere((_, item) => now.difference(item.time).inSeconds > 10);
    for (final peer in peers()) {
      final nonce = randomHex(16);
      _pending[nonce] = (peer: peer, time: now);
      final packet = DiscoveryProof.query(peer, nonce);
      _send(packet, InternetAddress('255.255.255.255'), discoveryPort);
      _send(packet, InternetAddress(peer.host), discoveryPort);
    }
  }

  void _receive(Datagram datagram) {
    if (datagram.data.length > 2048 ||
        !isLocalAddress(datagram.address.address)) {
      return;
    }
    try {
      final packet =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (packet['type'] == 'query') {
        final local = own();
        if (DiscoveryProof.verifyQuery(packet, local) &&
            DateTime.now().difference(_lastReply).inMilliseconds > 100) {
          _lastReply = DateTime.now();
          _send(
            DiscoveryProof.reply(local, packet['nonce'] as String),
            datagram.address,
            datagram.port,
          );
        }
      } else if (packet['type'] == 'here') {
        final nonce = packet['nonce'];
        final pending = _pending[nonce];
        if (pending != null &&
            DateTime.now().difference(pending.time).inSeconds <= 10 &&
            DiscoveryProof.verifyReply(packet, pending.peer, nonce as String)) {
          _pending.remove(nonce);
          onFound(
            pending.peer.copyWith(
              host: datagram.address.address,
              port: packet['port'] as int,
            ),
          );
        }
      }
    } catch (_) {
      /* Ignore unrelated or malformed LAN packets. */
    }
  }

  Future<void> close() async {
    _timer?.cancel();
    await _subscription?.cancel();
    _socket?.close();
  }
}

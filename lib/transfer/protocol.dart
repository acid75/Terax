import 'dart:convert';
import 'dart:math';

const maxFileBytes = 1024 * 1024 * 1024;

String randomHex([int count = 32]) {
  final random = Random.secure();
  return List.generate(
    count,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

bool isLocalAddress(String host) {
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((n) => n == null || n < 0 || n > 255)) {
    return false;
  }
  return parts[0] == 10 ||
      parts[0] == 127 ||
      (parts[0] == 192 && parts[1] == 168) ||
      (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31) ||
      (parts[0] == 169 && parts[1] == 254);
}

class PairingInfo {
  const PairingInfo({
    required this.host,
    required this.port,
    required this.token,
    required this.fingerprint,
    required this.name,
  });
  final String host, token, fingerprint, name;
  final int port;
  String encode() =>
      'terax:1:${jsonEncode([host, port, token, fingerprint, name])}';

  static PairingInfo parse(String code) {
    try {
      code = code.trim();
      if (!code.startsWith('terax:1:') || code.length > 4096) {
        throw const FormatException();
      }
      final data = jsonDecode(code.substring(8)) as List<dynamic>;
      if (data.length != 5) throw const FormatException();
      final host = data[0] as String;
      final port = data[1] as int;
      final token = data[2] as String;
      final fingerprint = data[3] as String;
      final name = data[4] as String;
      final hex = RegExp(r'^[a-f0-9]{64}$');
      if (!isLocalAddress(host) ||
          port < 1 ||
          port > 65535 ||
          !hex.hasMatch(token) ||
          !hex.hasMatch(fingerprint) ||
          name.isEmpty ||
          name.length > 80) {
        throw const FormatException();
      }
      return PairingInfo(
        host: host,
        port: port,
        token: token,
        fingerprint: fingerprint,
        name: name,
      );
    } catch (_) {
      throw const FormatException(
        'El código de Terax no es válido. Genera uno nuevo en el otro equipo.',
      );
    }
  }

  PairingInfo copyWith({
    String? host,
    int? port,
    String? token,
    String? fingerprint,
  }) => PairingInfo(
    host: host ?? this.host,
    port: port ?? this.port,
    token: token ?? this.token,
    fingerprint: fingerprint ?? this.fingerprint,
    name: name,
  );
}

String safeFileName(String name) {
  var result = name
      .replaceAll('\\', '/')
      .split('/')
      .last
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]'), '_')
      .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (result.isEmpty) result = 'archivo';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(result)) {
    result = 'archivo_$result';
  }
  if (result.length > 140) result = result.substring(result.length - 140);
  return result;
}

bool secureEquals(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

class TransferException implements Exception {
  const TransferException(this.message);
  final String message;
  @override
  String toString() => message;
}

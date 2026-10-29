import 'dart:convert';
import 'dart:io';

enum SharedMessageKind { text, link }

class SharedMessage {
  const SharedMessage._(this.kind, this.text);
  factory SharedMessage.text(String value) {
    if (value.trim().isEmpty || value.contains('\u0000')) {
      throw const FormatException('Escribe algo para enviar.');
    }
    return SharedMessage._(SharedMessageKind.text, value);
  }
  factory SharedMessage.link(String value) {
    final v = value.trim();
    if (validLink(v) == null) {
      throw const FormatException(
        'Escribe un enlace completo que empiece con https:// o http://.',
      );
    }
    return SharedMessage._(SharedMessageKind.link, v);
  }
  static const maxBytes = 64 * 1024;
  static const suffix = '.terax-message.json';
  final SharedMessageKind kind;
  final String text;
  Uri? get uri => kind == SharedMessageKind.link ? validLink(text) : null;
  String get label =>
      kind == SharedMessageKind.link ? 'Enlace · ${uri!.host}' : 'Texto';
  List<int> encode() {
    final bytes = utf8.encode(
      jsonEncode({
        'format': 'terax.message',
        'version': 1,
        'kind': kind.name,
        'text': text,
      }),
    );
    if (bytes.length > maxBytes) {
      throw const FormatException('El mensaje supera el máximo de 64 KB.');
    }
    return bytes;
  }

  static Uri? validLink(String value) {
    try {
      if (RegExp(r'\s').hasMatch(value)) return null;
      final uri = Uri.parse(value);
      return ['http', 'https'].contains(uri.scheme) &&
              uri.hasAuthority &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty
          ? uri
          : null;
    } catch (_) {
      return null;
    }
  }

  static SharedMessage? decode(List<int> bytes) {
    if (bytes.length > maxBytes) return null;
    try {
      final obj = jsonDecode(utf8.decode(bytes));
      if (obj is! Map ||
          obj['format'] != 'terax.message' ||
          obj['version'] != 1 ||
          obj['text'] is! String) {
        return null;
      }
      return switch (obj['kind']) {
        'text' => SharedMessage.text(obj['text'] as String),
        'link' => SharedMessage.link(obj['text'] as String),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  static bool matchesName(String name) => name.endsWith(suffix);
  static Future<SharedMessage?> read(File file, {required String name}) async {
    if (!matchesName(name)) return null;
    try {
      if (await file.length() > maxBytes) return null;
      final bytes = <int>[];
      await for (final chunk in file.openRead()) {
        if (bytes.length + chunk.length > maxBytes) return null;
        bytes.addAll(chunk);
      }
      return decode(bytes);
    } catch (_) {
      return null;
    }
  }

  static String displayName(String name) {
    if (!matchesName(name)) return name;
    final stem = name.substring(0, name.length - suffix.length);
    return stem.startsWith('Texto_')
        ? 'Texto'
        : stem.startsWith('Enlace_')
        ? 'Enlace'
        : stem;
  }
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/sharing/shared_message.dart';

void main() {
  test(
    'text and links round trip UTF8 without losing whitespace or Unicode',
    () {
      for (final message in [
        SharedMessage.text(' Hola 👋\nsegunda línea '),
        SharedMessage.link('https://example.com/ruta?q=niño'),
      ]) {
        final decoded = SharedMessage.decode(message.encode());
        expect(decoded?.text, message.text);
        expect(decoded?.kind, message.kind);
      }
    },
  );
  test('links require an explicit HTTP(S) absolute URL', () {
    for (final value in [
      'file:///C:/x.exe',
      'javascript:alert(1)',
      'mailto:a@b.com',
      'https://',
      'https://user:pass@example.com',
      'https://example.com/a b',
    ]) {
      expect(
        () => SharedMessage.link(value),
        throwsFormatException,
        reason: value,
      );
    }
    expect(
      SharedMessage.link('https://192.168.1.4:8080/a').uri?.host,
      '192.168.1.4',
    );
  });
  test(
    'malformed versions, disguised text and oversized content are not messages',
    () {
      for (final bytes in [
        utf8.encode('ordinary text'),
        utf8.encode(
          '{"format":"terax.message","version":2,"kind":"text","text":"hi"}',
        ),
        [255, 254],
        List<int>.filled(SharedMessage.maxBytes + 1, 32),
      ]) {
        expect(SharedMessage.decode(bytes), isNull);
      }
      expect(
        () => SharedMessage.text('🙂' * SharedMessage.maxBytes).encode(),
        throwsFormatException,
      );
      expect(() => SharedMessage.text('  '), throwsFormatException);
    },
  );
}

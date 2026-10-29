import 'package:flutter_test/flutter_test.dart';
import 'package:terax/transfer/open_policy.dart';

void main() {
  test(
    'common documents and photos can open after verification, scripts cannot',
    () {
      for (final name in [
        'foto.JPG',
        'informe.pdf',
        'contrato.docx',
        'tabla.xlsx',
        'diapositivas.pptx',
        'nota.txt',
      ]) {
        expect(autoOpenKind(name), isNot(AutoOpenKind.none), reason: name);
      }
      for (final name in [
        'instalar.exe',
        'enlace.url',
        'macro.docm',
        'script.ps1',
        'pagina.html',
        'foto.png.exe',
      ]) {
        expect(autoOpenKind(name), AutoOpenKind.none, reason: name);
      }
      expect(
        validDocumentHeader('informe.pdf', [0x25, 0x50, 0x44, 0x46, 0x2d]),
        isTrue,
      );
      expect(validDocumentHeader('informe.pdf', [0x4d, 0x5a, 0, 0]), isFalse);
      expect(validDocumentHeader('contrato.docx', [0x50, 0x4b, 3, 4]), isTrue);
    },
  );
}

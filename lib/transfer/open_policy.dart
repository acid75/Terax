import 'dart:convert';
import 'package:path/path.dart' as p;

enum AutoOpenKind { none, image, document }

AutoOpenKind autoOpenKind(String name) {
  final extension = p.extension(name).toLowerCase();
  if ({'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'}.contains(extension)) {
    return AutoOpenKind.image;
  }
  if ({
    '.pdf',
    '.docx',
    '.xlsx',
    '.pptx',
    '.odt',
    '.ods',
    '.odp',
    '.txt',
    '.csv',
    '.md',
    '.rtf',
  }.contains(extension)) {
    return AutoOpenKind.document;
  }
  return AutoOpenKind.none;
}

bool validDocumentHeader(String name, List<int> bytes) {
  final extension = p.extension(name).toLowerCase();
  if (extension == '.pdf') {
    return ascii.decode(bytes.take(5).toList(), allowInvalid: true) == '%PDF-';
  }
  if ({'.docx', '.xlsx', '.pptx', '.odt', '.ods', '.odp'}.contains(extension)) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 3 &&
        bytes[3] == 4;
  }
  if (extension == '.rtf') {
    return ascii.decode(bytes.take(5).toList(), allowInvalid: true) == r'{\rtf';
  }
  if ({'.txt', '.csv', '.md'}.contains(extension)) {
    return !bytes.contains(0) &&
        !(bytes.length >= 2 && bytes[0] == 0x4d && bytes[1] == 0x5a);
  }
  return false;
}

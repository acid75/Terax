import 'dart:io';
import 'package:flutter/services.dart';
import '../library/library_service.dart';

class SharedContent {
  const SharedContent({this.text, this.files = const [], this.warning});
  final String? text;
  final String? warning;
  final List<LibraryItem> files;
}

abstract final class AndroidShareBridge {
  static const _library = MethodChannel('terax/library');
  static const _share = MethodChannel('terax/share');
  static Future<List<LibraryItem>> pickFiles() async {
    final raw = await _library.invokeMethod<Object?>('chooseFiles');
    if (raw is List &&
        raw.whereType<Map>().any(
          (row) => row['size'] is num && (row['size'] as num) > 1073741824,
        )) {
      throw StateError(
        'El máximo por archivo es 1 GB. Selecciona un archivo más pequeño.',
      );
    }
    return _files(raw);
  }

  static Future<SharedContent?> takeInitial() async =>
      _parse(await _share.invokeMethod<Object?>('takeInitial'));
  static void listen(void Function(SharedContent) callback) {
    _share.setMethodCallHandler((call) async {
      if (call.method == 'shared') {
        final content = _parse(call.arguments);
        if (content != null) callback(content);
      }
    });
    // Native buffers arrivals until this handshake, including engine reattachment.
    _share.invokeMethod<void>('listen').catchError((Object _) {});
  }

  static void stopListening() {
    _share.setMethodCallHandler(null);
    _share.invokeMethod<void>('stopListening').catchError((Object _) {});
  }

  static Future<bool> openLink(Uri uri) async {
    if (!uri.isAbsolute ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return false;
    }
    try {
      return await _share.invokeMethod<bool>('openLink', {
            'url': uri.toString(),
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static SharedContent? _parse(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'] is String ? raw['text'] as String : null;
    final files = _files(raw['files']);
    final warning = raw['warning'] is String ? raw['warning'] as String : null;
    if ((text == null || text.isEmpty) &&
        files.isEmpty &&
        (warning == null || warning.isEmpty)) {
      return null;
    }
    return SharedContent(text: text, files: files, warning: warning);
  }

  static List<LibraryItem> _files(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .where(
          (row) =>
              row['id'] is String &&
              row['name'] is String &&
              ((row['size'] as num?) ?? 0) <= 1073741824,
        )
        .map((row) {
          final id = row['id'] as String;
          final name = row['name'] as String;
          final path = row['path'] as String?;
          return LibraryItem(
            id: id,
            name: name,
            isDirectory: false,
            isImage: row['isImage'] == true,
            size: (row['size'] as num?)?.toInt() ?? 0,
            modified: DateTime.fromMillisecondsSinceEpoch(0),
            localFile: path == null ? null : File(path),
            resolver: () async {
              final path = await _library.invokeMethod<String>('materialize', {
                'uri': id,
                'name': name,
              });
              if (path == null) {
                throw StateError('El archivo ya no está disponible.');
              }
              return File(path);
            },
          );
        })
        .toList(growable: false);
  }
}

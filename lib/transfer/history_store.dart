import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'history_entry.dart';

abstract interface class TransferHistoryStore {
  Future<List<HistoryEntry>> load();
  Future<void> save(List<HistoryEntry> entries);
}

/// Local metadata only: saving or clearing history never touches payload files.
class FileTransferHistoryStore implements TransferHistoryStore {
  FileTransferHistoryStore({required this.directory});

  static const maxEntries = 50;
  static const maxBytes = 1024 * 1024;
  final Future<Directory> Function() directory;
  Future<void> _pending = Future<void>.value();

  Future<File> _file() async =>
      File(p.join((await directory()).path, 'Terax', 'history.json'));

  @override
  Future<List<HistoryEntry>> load() async {
    await _pending;
    try {
      final file = await _file();
      // Bound the stream too, in case another process grows the file after stat.
      if (await file.length() > maxBytes) return [];
      final bytes = <int>[];
      await for (final chunk in file.openRead()) {
        if (bytes.length + chunk.length > maxBytes) return [];
        bytes.addAll(chunk);
      }
      final document = jsonDecode(utf8.decode(bytes));
      if (document is! Map ||
          document['version'] != 1 ||
          document['entries'] is! List) {
        return [];
      }
      final entries = <HistoryEntry>[];
      for (final row in document['entries'] as List) {
        if (row is! Map) continue;
        final name = row['name'];
        final size = row['size'];
        final incoming = row['incoming'];
        final path = row['path'];
        final timestamp = row['time'];
        if (name is! String ||
            name.isEmpty ||
            size is! int ||
            size < 0 ||
            incoming is! bool ||
            path is! String ||
            path.isEmpty ||
            path.contains('\u0000') ||
            timestamp is! String) {
          continue;
        }
        final time = DateTime.tryParse(timestamp);
        if (time == null) continue;
        entries.add(
          HistoryEntry(
            name: name,
            size: size,
            incoming: incoming,
            file: File(path),
            time: time,
          ),
        );
      }
      return _newest(entries);
    } on FileSystemException {
      return [];
    } on FormatException {
      return [];
    }
  }

  static List<HistoryEntry> _newest(List<HistoryEntry> entries) {
    final sorted = List<HistoryEntry>.of(entries)
      ..sort((a, b) => b.time.compareTo(a.time));
    return sorted.take(maxEntries).toList();
  }

  @override
  Future<void> save(List<HistoryEntry> entries) {
    // Encode before yielding: caller mutations cannot change this queued write.
    final bytes = utf8.encode(
      jsonEncode({
        'version': 1,
        'entries': _newest(entries)
            .map(
              (entry) => {
                'name': entry.name,
                'size': entry.size,
                'incoming': entry.incoming,
                'path': entry.file.path,
                'time': entry.time.toIso8601String(),
              },
            )
            .toList(),
      }),
    );
    final operation = _pending.then((_) async {
      if (bytes.length > maxBytes) {
        throw const FileSystemException('Transfer history exceeds size limit');
      }
      final file = await _file();
      await file.parent.create(recursive: true);
      final stagingDirectory = await file.parent.createTemp('.history-');
      final temporary = File(p.join(stagingDirectory.path, 'history.json'));
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        // File.rename replaces an existing file on Windows as well. Never
        // pre-delete the destination: a failed replacement leaves it intact.
        await temporary.rename(file.path);
      } finally {
        await stagingDirectory.delete(recursive: true);
      }
    });
    // A failed write is reported to its caller but does not poison later saves.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

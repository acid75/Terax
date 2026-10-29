import 'dart:io';

class HistoryEntry {
  HistoryEntry({
    required this.name,
    required this.size,
    required this.incoming,
    required this.file,
    required this.time,
  });

  final String name;
  final int size;
  final bool incoming;
  final File file;
  final DateTime time;
}

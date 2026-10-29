import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:terax/transfer/history_entry.dart';
import 'package:terax/transfer/history_store.dart';

void main() {
  late Directory root;
  late FileTransferHistoryStore store;
  late File metadata;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('terax-history-test-');
    store = FileTransferHistoryStore(directory: () async => root);
    metadata = File(p.join(root.path, 'Terax', 'history.json'));
  });
  tearDown(() async => root.delete(recursive: true));

  HistoryEntry entry(int index, {File? file}) => HistoryEntry(
    name: 'Archivo $index á.pdf',
    size: index,
    incoming: index.isEven,
    file: file ?? File(p.join(root.path, 'missing-$index.pdf')),
    time: DateTime.utc(2026, 1, 1).add(Duration(seconds: index)),
  );

  Future<void> writeDocument(Object document) async {
    await metadata.parent.create(recursive: true);
    await metadata.writeAsString(jsonEncode(document));
  }

  test(
    'round trip preserves metadata and missing or external payload paths',
    () async {
      final external = File(p.join(root.parent.path, 'user-selected-file.pdf'));
      final original = entry(3, file: external);
      await store.save([original]);
      final restored = await store.load();
      expect(restored, hasLength(1));
      expect(restored.single.name, original.name);
      expect(restored.single.size, original.size);
      expect(restored.single.incoming, original.incoming);
      expect(restored.single.file.path, external.path);
      expect(restored.single.time, original.time);
    },
  );

  test(
    'missing, malformed, oversized and unknown schema return empty',
    () async {
      expect(await store.load(), isEmpty);
      await writeDocument({'version': 99, 'entries': []});
      expect(await store.load(), isEmpty);
      await metadata.writeAsString('{broken');
      expect(await store.load(), isEmpty);
      await metadata.writeAsString(
        'x' * (FileTransferHistoryStore.maxBytes + 1),
      );
      expect(await store.load(), isEmpty);
    },
  );

  test('bad rows are skipped without losing valid rows', () async {
    await store.save([entry(1)]);
    final document = jsonDecode(await metadata.readAsString()) as Map;
    final valid = (document['entries'] as List).single as Map;
    document['entries'] = [
      null,
      {'name': 'incomplete'},
      {...valid, 'size': -1},
      {...valid, 'incoming': 'true'},
      {...valid, 'time': 'invalid'},
      valid,
    ];
    await writeDocument(document);
    expect((await store.load()).single.name, entry(1).name);
  });

  test(
    'save keeps 50 newest and replacement leaves no staging files',
    () async {
      await store.save(List.generate(75, entry));
      final loaded = await store.load();
      expect(loaded, hasLength(50));
      expect(loaded.first.size, 74);
      expect(loaded.last.size, 25);
      await store.save([entry(4)]);
      expect((await store.load()).single.size, 4);
      expect(await metadata.parent.list().length, 1);
    },
  );

  test('queued saves snapshot input and execute in invocation order', () async {
    final values = [entry(1)];
    final first = store.save(values);
    values.clear();
    await first;
    expect((await store.load()).single.size, 1);
    final saves = List.generate(20, (index) => store.save([entry(index)]));
    await Future.wait(saves);
    expect((await store.load()).single.size, 19);
  });

  test('clearing metadata never removes transferred files', () async {
    final payload = File(p.join(root.path, 'payload.txt'));
    await payload.writeAsString('keep me');
    await store.save([entry(1, file: payload)]);
    await store.save([]);
    expect(await store.load(), isEmpty);
    expect(await payload.readAsString(), 'keep me');
  });

  test(
    'failed save preserves old history and allows subsequent saves',
    () async {
      await store.save([entry(1)]);
      final huge = HistoryEntry(
        name: 'x' * FileTransferHistoryStore.maxBytes,
        size: 0,
        incoming: true,
        file: File('missing'),
        time: DateTime.now(),
      );
      await expectLater(
        store.save([huge]),
        throwsA(isA<FileSystemException>()),
      );
      expect((await store.load()).single.size, 1);
      await store.save([entry(2)]);
      expect((await store.load()).single.size, 2);
    },
  );
}

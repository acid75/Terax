import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/library/library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('terax-library-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
    'authorized folder selection resets breadcrumbs without discarding roots',
    () async {
      final first = await Directory('${temp.path}/Trabajo').create();
      final second = await Directory('${temp.path}/Descargas').create();
      final child = await Directory('${first.path}/Facturas').create();
      final service = LibraryService(
        android: false,
        roots: {
          LibraryKind.document: [first, second],
        },
      );
      await service.load(LibraryKind.document);
      final roots = service.authorizedFolders;
      await service.openAuthorizedFolder(
        roots.firstWhere((r) => r.name == 'Trabajo'),
      );
      await service.openFolder(
        service.items.firstWhere((i) => i.name == 'Facturas'),
      );
      expect(service.folderTrail, ['Trabajo', 'Facturas']);
      expect(service.authorizedFolders.length, 2);
      await service.openAuthorizedFolder(
        roots.firstWhere((r) => r.name == 'Descargas'),
      );
      expect(service.folderTrail, ['Descargas']);
      expect(
        service.isRootActive(roots.firstWhere((r) => r.name == 'Descargas')),
        isTrue,
      );
      await service.goBack();
      expect(service.folderTrail, isEmpty);
      expect(service.items.length, 2);
      expect(await child.exists(), isTrue);
      service.dispose();
    },
  );
  test(
    'browses folders and resolves only explicitly chosen local files',
    () async {
      final folder = await Directory('${temp.path}/nested').create();
      final file = await File(
        '${folder.path}/hello.txt',
      ).writeAsString('hello');
      final service = LibraryService(
        android: false,
        roots: {
          LibraryKind.document: [temp],
        },
      );
      await service.load(LibraryKind.document);
      expect(service.items.single.isDirectory, isTrue);
      await service.openFolder(service.items.single);
      expect(service.canGoBack, isTrue);
      expect(
        await (await service.items.single.resolve()).readAsString(),
        'hello',
      );
      expect(
        await FileSystemEntity.identical(
          (await service.items.single.resolve()).path,
          file.path,
        ),
        isTrue,
      );
      await service.goBack();
      expect(service.items.single.name, 'nested');
      service.dispose();
    },
  );
  test('missing roots yield a useful error without throwing', () async {
    final service = LibraryService(
      android: false,
      roots: {
        LibraryKind.document: [Directory('${temp.path}/missing')],
      },
    );
    await service.load(LibraryKind.document);
    expect(service.loading, isFalse);
    expect(service.error, isNotNull);
    service.dispose();
  });
  test(
    'photo browser filters documents and stale files fail on selection',
    () async {
      final image = await File(
        '${temp.path}/image.jpg',
      ).writeAsBytes([1, 2, 3]);
      await File('${temp.path}/private.txt').writeAsString('not a photo');
      final service = LibraryService(
        android: false,
        roots: {
          LibraryKind.photo: [temp],
        },
      );
      await service.load(LibraryKind.photo);
      expect(service.items.map((item) => item.name), ['image.jpg']);
      final selected = service.items.single;
      await image.delete();
      await expectLater(selected.resolve(), throwsStateError);
      service.dispose();
    },
  );
  test(
    'newest photos appear before older photos regardless of filename',
    () async {
      final old = await File('${temp.path}/a.jpg').writeAsBytes([1]);
      final recent = await File('${temp.path}/z.jpg').writeAsBytes([2]);
      await old.setLastModified(DateTime(2020));
      await recent.setLastModified(DateTime(2025));
      final service = LibraryService(
        android: false,
        roots: {
          LibraryKind.photo: [temp],
        },
      );
      await service.load(LibraryKind.photo);
      expect(service.items.map((item) => item.name), ['z.jpg', 'a.jpg']);
      service.dispose();
    },
  );
  test('late folder results cannot overwrite a newer load', () async {
    const channel = MethodChannel('terax/library');
    final first = Completer<List<dynamic>>();
    var count = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          count++;
          if (count == 1) return first.future;
          return [
            {'id': 'new', 'name': 'Nueva', 'directory': false},
          ];
        });
    final service = LibraryService(android: true);
    final pending = service.load(LibraryKind.document);
    await Future<void>.delayed(Duration.zero);
    await service.load(LibraryKind.document);
    first.complete([
      {'id': 'old', 'name': 'Vieja', 'directory': false},
    ]);
    await pending;
    expect(service.items.single.id, 'new');
    expect(service.loading, isFalse);
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/sharing/android_share_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const library = MethodChannel('terax/library');
  const share = MethodChannel('terax/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(library, null);
    messenger.setMockMethodCallHandler(share, null);
    AndroidShareBridge.stopListening();
  });
  test(
    'picked content URI resolves through existing library channel',
    () async {
      messenger.setMockMethodCallHandler(library, (call) async {
        if (call.method == 'chooseFiles') {
          return [
            {
              'id': 'content://docs/1',
              'name': 'uno.pdf',
              'size': 12,
              'isImage': false,
            },
          ];
        }
        expect(call.method, 'materialize');
        expect(call.arguments, {'uri': 'content://docs/1', 'name': 'uno.pdf'});
        return '/missing/uno.pdf';
      });
      final items = await AndroidShareBridge.pickFiles();
      expect(items.single.name, 'uno.pdf');
      expect(items.single.localFile, isNull);
      await expectLater(items.single.resolve(), throwsStateError);
    },
  );
  test(
    'oversized picked files report a limit rather than silently disappearing',
    () async {
      messenger.setMockMethodCallHandler(
        library,
        (_) async => [
          {
            'id': 'content://downloads/large',
            'name': 'large.zip',
            'size': 1073741825,
            'isImage': false,
          },
        ],
      );
      await expectLater(
        AndroidShareBridge.pickFiles(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('1 GB'),
          ),
        ),
      );
    },
  );
  test('initial share parses cached files and text', () async {
    messenger.setMockMethodCallHandler(
      share,
      (call) async => {
        'text': 'hola',
        'files': [
          {
            'id': 'content://shared/1',
            'path': '/cache/one.jpg',
            'name': 'one.jpg',
            'size': 2,
            'isImage': true,
          },
        ],
      },
    );
    final content = await AndroidShareBridge.takeInitial();
    expect(content!.text, 'hola');
    expect(content.files.single.localFile!.path, '/cache/one.jpg');
    expect(content.files.single.isImage, isTrue);
  });
  test('invalid links never reach native channel', () async {
    messenger.setMockMethodCallHandler(
      share,
      (_) async => fail('invalid link reached native'),
    );
    expect(
      await AndroidShareBridge.openLink(Uri.parse('file:///etc/a')),
      isFalse,
    );
    expect(
      await AndroidShareBridge.openLink(Uri.parse('https:relative')),
      isFalse,
    );
  });
  test(
    'listener receives new shares and stops delivering after removal',
    () async {
      messenger.setMockMethodCallHandler(share, (_) async => null);
      final received = <SharedContent>[];
      AndroidShareBridge.listen(received.add);
      await messenger.handlePlatformMessage(
        'terax/share',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('shared', {'text': 'nuevo', 'files': []}),
        ),
        (_) {},
      );
      expect(received.single.text, 'nuevo');
      AndroidShareBridge.stopListening();
      await messenger.handlePlatformMessage(
        'terax/share',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('shared', {'text': 'otro', 'files': []}),
        ),
        (_) {},
      );
      expect(received, hasLength(1));
    },
  );
  test('valid HTTP link returns native handler outcome', () async {
    messenger.setMockMethodCallHandler(share, (call) async {
      expect(call.method, 'openLink');
      expect(call.arguments, {'url': 'https://example.com/a'});
      return true;
    });
    expect(
      await AndroidShareBridge.openLink(Uri.parse('https://example.com/a')),
      isTrue,
    );
  });
  test('empty and oversized incoming content is ignored', () async {
    messenger.setMockMethodCallHandler(
      share,
      (_) async => {
        'files': [
          {'id': 'content://large/1', 'name': 'huge', 'size': 1073741825},
        ],
      },
    );
    expect(await AndroidShareBridge.takeInitial(), isNull);
  });
  test('warning-only shares remain visible when every file failed', () async {
    messenger.setMockMethodCallHandler(
      share,
      (_) async => {
        'warning':
            'No se pudieron leer algunos archivos compartidos o superan el límite de 1 GB.',
        'files': [],
      },
    );
    final content = await AndroidShareBridge.takeInitial();
    expect(content, isNotNull);
    expect(content!.warning, contains('1 GB'));
    expect(content.files, isEmpty);
  });
  test('warning preserves valid files in a partially accepted share', () async {
    messenger.setMockMethodCallHandler(
      share,
      (_) async => {
        'warning': 'Un archivo no se pudo leer.',
        'files': [
          {'id': 'content://ok/1', 'name': 'ok.pdf', 'size': 1},
        ],
      },
    );
    final content = await AndroidShareBridge.takeInitial();
    expect(content!.warning, 'Un archivo no se pudo leer.');
    expect(content.files.single.name, 'ok.pdf');
  });
}

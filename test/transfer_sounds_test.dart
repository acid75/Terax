import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/sharing/transfer_sounds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('terax/sounds');
  late Directory root;
  late TransferSounds sounds;
  late List<MethodCall> calls;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('terax-sounds-test');
    calls = [];
    sounds = TransferSounds(directory: () async => root);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'play' ? true : null;
        });
  });
  tearDown(() async {
    sounds.dispose();
    await Future<void>.delayed(Duration.zero);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });
  test('ships the exact user-selected sending and received MP3 files', () async {
    expect(await sounds.outgoing(), isTrue);
    expect(await sounds.incoming(), isTrue);
    final paths = calls
        .where((call) => call.method == 'play')
        .map((call) => (call.arguments as Map)['path'] as String)
        .toList();
    expect(paths[0], endsWith('departure-v6.mp3'));
    expect(paths[1], endsWith('arrival-v6.mp3'));
    for (var i = 0; i < paths.length; i++) {
      final bytes = await File(paths[i]).readAsBytes();
      final asset = await rootBundle.load(
        i == 0
            ? 'assets/audio/terax-departure-v6.mp3'
            : 'assets/audio/terax-arrival-v6.mp3',
      );
      expect(
        bytes,
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      expect(
        sha256.convert(bytes).toString(),
        i == 0
            ? 'a0bb9c1c3592f50240ae0d4cd500fb704f2e92f82768032fb7cafea514d04246'
            : '42f6807a4ca04dac647ae192de5b0d04483af07fb510b6be72fa832c8e74cfa0',
      );
    }
  });
  test('MP3 version bypasses previous WAV cache on upgrade', () async {
    final old = File('${root.path}/transfer_sounds/departure-v1.wav');
    await old.parent.create(recursive: true);
    await old.writeAsBytes([1, 2, 3]);
    await sounds.outgoing();
    expect((calls.first.arguments as Map)['path'], endsWith('-v6.mp3'));
    expect(await old.readAsBytes(), [1, 2, 3]);
  });
  test('disabled is persisted and never asks native player to play', () async {
    await sounds.setEnabled(false);
    calls.clear();
    expect(await sounds.outgoing(), isFalse);
    expect(await sounds.incoming(), isFalse);
    expect(calls, isEmpty);
    final restored = TransferSounds(directory: () async => root);
    await restored.load();
    expect(restored.enabled, isFalse);
    await restored.setEnabled(true);
    restored.dispose();
  });
  test('corrupt or oversized preferences preserve enabled default', () async {
    await File('${root.path}/transfer_sounds.json').writeAsString('x' * 2048);
    await sounds.load();
    expect(sounds.enabled, isTrue);
  });
  test(
    'missing player is optional and disposed service stays silent',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(await sounds.outgoing(), isFalse);
      sounds.dispose();
      expect(await sounds.incoming(), isFalse);
    },
  );
}

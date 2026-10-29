import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/sharing/audio_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('terax/library');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'startup requests audio access once through Android and settings can retry',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      expect(await AudioAccess.request(automatic: true), isTrue);
      expect(await AudioAccess.request(), isTrue);
      expect(calls.map((call) => call.method), [
        'requestAudioAccess',
        'requestAudioAccess',
      ]);
      expect(calls[0].arguments, {'automatic': true});
      expect(calls[1].arguments, {'automatic': false});
    },
  );
  test(
    'denial or unavailable plugin is not a playback or transfer failure',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      expect(await AudioAccess.request(automatic: true), isFalse);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await AudioAccess.request(), isFalse);
    },
  );
}

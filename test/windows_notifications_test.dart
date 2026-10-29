import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/ui/windows_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('terax/files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('passes the verified name and returns native acceptance', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'notifyReceived');
      expect(call.arguments, {'name': 'Foto 🐈.png'});
      return true;
    });
    expect(await WindowsNotifications.received('Foto 🐈.png'), isTrue);
  });

  test('returns false when native decides no balloon is needed', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    expect(await WindowsNotifications.received('foto.png'), isFalse);
  });

  test('returns false for an unavailable native implementation', () async {
    expect(await WindowsNotifications.received('foto.png'), isFalse);
  });

  test('returns false for null and platform errors', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await WindowsNotifications.received('foto.png'), isFalse);
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await WindowsNotifications.received('foto.png'), isFalse);
  });
}

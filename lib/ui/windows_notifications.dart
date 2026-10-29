import 'package:flutter/services.dart';

/// Native tray balloons; Windows may suppress these according to user settings.
/// Call only after integrity verification. Clicking a balloon restores Terax,
/// where receipt actions are available; balloons cannot host buttons/thumbnails.
abstract final class WindowsNotifications {
  static const _channel = MethodChannel('terax/files');

  /// Returns whether Windows accepted a balloon for a hidden/minimized window.
  static Future<bool> received(String name) async {
    try {
      return await _channel.invokeMethod<bool>('notifyReceived', {
            'name': name,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

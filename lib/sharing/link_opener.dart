import 'dart:io';
import 'package:flutter/services.dart';
import 'android_share_bridge.dart';
import 'shared_message.dart';

abstract final class LinkOpener {
  static Future<bool> open(Uri uri) async {
    if (SharedMessage.validLink(uri.toString()) == null) return false;
    try {
      return Platform.isWindows
          ? await const MethodChannel(
                  'terax/files',
                ).invokeMethod<bool>('openLink', uri.toString()) ??
                false
          : Platform.isAndroid
          ? await AndroidShareBridge.openLink(uri)
          : false;
    } catch (_) {
      return false;
    }
  }
}

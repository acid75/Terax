import 'package:flutter/services.dart';

/// Access to the user's shared audio files; never gates bundled sound playback.
class AudioAccess {
  static const _channel = MethodChannel('terax/library');
  static Future<bool> request({bool automatic = false}) async {
    try {
      return await _channel.invokeMethod<bool>('requestAudioAccess', {
            'automatic': automatic,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

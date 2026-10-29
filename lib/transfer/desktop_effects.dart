import 'package:flutter/services.dart';

/// The native renderer holds desktop pixels only for the duration of the wave.
class DesktopEffects {
  const DesktopEffects();
  static const _channel = MethodChannel('terax/files');
  Future<bool> play({required bool reducedMotion}) async =>
      await _channel.invokeMethod<bool>('desktopWave', {
        'reducedMotion': reducedMotion,
      }) ??
      false;
  Future<void> stop() => _channel.invokeMethod<void>('stopDesktopWave');
}

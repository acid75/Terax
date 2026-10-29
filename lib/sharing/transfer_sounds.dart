import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Complementary, single-pass cues; audio never participates in transfer success.
class TransferSounds {
  TransferSounds({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  static const departureDuration = Duration(milliseconds: 4032);
  static const arrivalDuration = Duration(milliseconds: 2926);
  static const _channel = MethodChannel('terax/sounds');
  final Future<Directory> Function() _directory;
  bool _enabled = true;
  bool _disposed = false;
  Future<void>? _loading;
  Directory? _root;
  bool get enabled => _enabled;
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      _root = await _directory();
      final file = File(p.join(_root!.path, 'transfer_sounds.json'));
      if (await file.exists() && await file.length() <= 1024) {
        final value = jsonDecode(await file.readAsString());
        if (value is Map && value['enabled'] is bool) {
          _enabled = value['enabled'] as bool;
        }
      }
    } catch (_) {
      /* Optional preference. */
    }
  }

  Future<void> setEnabled(bool value) async {
    await load();
    if (_disposed) return;
    _enabled = value;
    if (!value) await _stop();
    try {
      final root = _root ?? await _directory();
      await root.create(recursive: true);
      await File(
        p.join(root.path, 'transfer_sounds.json'),
      ).writeAsString(jsonEncode({'enabled': value}), flush: true);
    } catch (_) {
      /* Read-only profiles must not interrupt transfers. */
    }
  }

  Future<bool> outgoing() => _play(false);
  Future<bool> incoming() => _play(true);
  Future<bool> _play(bool incoming) async {
    await load();
    if (!_enabled || _disposed) return false;
    try {
      final root = _root ?? await _directory();
      final cache = Directory(p.join(root.path, 'transfer_sounds'));
      await cache.create(recursive: true);
      final file = File(
        p.join(cache.path, incoming ? 'arrival-v6.mp3' : 'departure-v6.mp3'),
      );
      final asset = await rootBundle.load(
        incoming
            ? 'assets/audio/terax-arrival-v6.mp3'
            : 'assets/audio/terax-departure-v6.mp3',
      );
      final audio = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      if (!await file.exists() || await file.length() != audio.length) {
        await file.writeAsBytes(audio, flush: true);
      }
      if (!_enabled || _disposed) return false;
      return await _channel.invokeMethod<bool>('play', {'path': file.path}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    unawaited(_stop());
  }
}

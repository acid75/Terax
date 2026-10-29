import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/services.dart';

class ProximityFilter {
  double? _average;
  int _stable = 0;
  bool near = false;
  bool update(int rssi) {
    if (rssi >= 0 || rssi < -110) return near;
    _average = _average == null
        ? rssi.toDouble()
        : _average! * .72 + rssi * .28;
    if (!near && _average! >= -55) {
      if (++_stable >= 3) {
        near = true;
        _stable = 0;
      }
    } else if (near && _average! < -65) {
      if (++_stable >= 2) {
        near = false;
        _stable = 0;
      }
    } else {
      _stable = 0;
    }
    return near;
  }
}

/// Experimental/internal manufacturer payload: TRX, version 2, fingerprint prefix.
/// This selects trusted peers only; HTTPS remains the authentication boundary.
String? trustedBeaconFingerprint(
  Advertisement advertisement,
  List<String> trusted,
) {
  for (final entry in advertisement.manufacturerSpecificData) {
    final data = entry.data;
    if (entry.id != 0xffff ||
        data.length != 20 ||
        data[0] != 0x54 ||
        data[1] != 0x52 ||
        data[2] != 0x58 ||
        data[3] != 2) {
      continue;
    }
    final prefix = data
        .skip(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final matches = trusted
        .where(
          (id) =>
              RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(id) &&
              id.toLowerCase().startsWith(prefix),
        )
        .toList();
    if (matches.length == 1) return matches.single;
  }
  return null;
}

/// BLE signals select/animate known equipment; HTTPS still authenticates files.
class BleProximity {
  BleProximity({
    required this.fingerprint,
    required this.trusted,
    required this.onStatus,
    required this.onNearby,
    // Public injection keeps platform integration testable without a radio.
    CentralManager? central,
    TargetPlatform? platform,
    DateTime Function()? now,
    // ignore: prefer_initializing_formals
  }) : _central = central,
       _platform = platform ?? defaultTargetPlatform,
       _now = now ?? DateTime.now;
  final TargetPlatform _platform;
  final DateTime Function() _now;
  bool _permissionGranted = false, _authorizing = false, _windowsReady = false;
  bool get ready => _windowsReady || _running;
  Future<void> openAppSettings() async {
    await _central?.showAppSettings();
  }

  final String fingerprint;
  final List<String> Function() trusted;
  final void Function(String) onStatus;
  final void Function(String?) onNearby;
  CentralManager? _central;
  static const _windows = MethodChannel('terax/proximity');
  Timer? _windowsTimer;
  DateTime? _windowsStartedAt;
  bool _polling = false;
  String? _lastStatus;
  void _status(String value) {
    if (_closed || value == _lastStatus) return;
    _lastStatus = value;
    onStatus(value);
  }

  bool _windowsUsed = false;
  Completer<void>? _activationDone;
  StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>?
  _stateSubscription;
  StreamSubscription<DiscoveredEventArgs>? _scanSubscription;
  Timer? _expiry;
  final _signals = <String, ProximityFilter>{};
  final _lastSeen = <String, DateTime>{};
  bool _running = false, _starting = false, _closed = false;
  String? _nearby;

  Future<void> start({bool requestPermission = false}) async {
    if (_closed || _authorizing) return;
    try {
      if (_platform == TargetPlatform.windows) {
        await _startWindows();
        if (_closed) return;
        _windowsTimer ??= Timer.periodic(
          const Duration(seconds: 2),
          (_) => unawaited(_pollWindows()),
        );
        return;
      } else if (_platform == TargetPlatform.android) {
        _central ??= CentralManager();
        _stateSubscription ??= _central!.stateChanged.listen(
          (_) => unawaited(_activate()),
        );
        _scanSubscription ??= _central!.discovered.listen(
          _discovered,
          onError: (_) =>
              _status('Cercanía no disponible. Puedes enviar por Wi-Fi.'),
        );
        if (requestPermission) {
          _authorizing = true;
          _status('Solicitando permiso de dispositivos cercanos…');
          // initialize() is asynchronous and clears pending authorization callbacks.
          // Let the plugin finish its first state query before opening the dialog.
          if (_central!.state == BluetoothLowEnergyState.unknown) {
            await _central!.stateChanged.first.timeout(
              const Duration(seconds: 5),
            );
          }
          if (_closed) return;
          _permissionGranted = await _central!.authorize();
          if (_closed) return;
          if (!_permissionGranted) {
            _status(
              'Permiso de dispositivos cercanos denegado. Actívalo en Ajustes > Aplicaciones > Terax > Permisos.',
            );
            return;
          }
        }
      } else {
        _status('Cercanía no disponible en este equipo.');
        return;
      }
      if (_closed) return;
      _expiry ??= Timer.periodic(const Duration(seconds: 2), (_) {
        if (_nearby != null &&
            _now().difference(_lastSeen[_nearby]!).inSeconds > 8) {
          _signals.remove(_nearby);
          _nearby = null;
          onNearby(null);
        }
      });
      await _activate();
    } catch (error) {
      if (!_closed) {
        _status(
          'No se pudo activar Bluetooth: $error. Revisa los permisos y vuelve a intentar.',
        );
      }
    } finally {
      _authorizing = false;
    }
  }

  String _windowsStatus(String? status) {
    _windowsReady = status == 'ready';
    if (_windowsReady) return 'Visible por Bluetooth';
    if (status == 'waiting' || status == 'starting') {
      return 'Preparando Bluetooth…';
    }
    if (status?.contains('BluetoothError=1)') ?? false) {
      return 'Bluetooth: radio no disponible (BluetoothError=1). Enciende Bluetooth; se reintentará automáticamente.';
    }
    return 'Bluetooth: ${status ?? 'sin respuesta'}. Puedes enviar por Wi-Fi.';
  }

  Future<void> _startWindows() async {
    if (_closed || _starting) return;
    _starting = true;
    _activationDone = Completer<void>();
    _windowsUsed = true;
    _windowsStartedAt = _now();
    try {
      final status = await _windows.invokeMethod<String>('start', fingerprint);
      if (!_closed) _status(_windowsStatus(status));
    } catch (error) {
      if (!_closed) _status(_windowsStatus(error.toString()));
    } finally {
      _starting = false;
      _activationDone!.complete();
    }
  }

  Future<void> _pollWindows() async {
    if (_closed || _starting || _polling) return;
    _polling = true;
    try {
      var status = await _windows.invokeMethod<String>('status');
      if (_closed) return;
      if ((status == 'waiting' || status == 'starting') &&
          _now().difference(_windowsStartedAt!).inSeconds > 15) {
        status =
            'sin iniciar después de 15 s; comprueba el adaptador y Bluetooth';
      }
      _status(_windowsStatus(status));
      if ((status?.startsWith('aborted') == true || status == 'stopped') &&
          _now().difference(_windowsStartedAt!).inSeconds >= 10) {
        await _startWindows();
      }
    } catch (error) {
      if (!_closed) _status(_windowsStatus(error.toString()));
    } finally {
      _polling = false;
    }
  }

  Future<void> _activate() async {
    if (_closed || _starting) return;
    final state = _central?.state;
    // 6.2.1 authorize() returns success without refreshing its cached state.
    // The native scanner still validates radio availability and permissions.
    final staleUnauthorized =
        state == BluetoothLowEnergyState.unauthorized && _permissionGranted;
    if (state != BluetoothLowEnergyState.poweredOn && !staleUnauthorized) {
      _running = false;
      _status(
        state == BluetoothLowEnergyState.poweredOff
            ? 'Enciende Bluetooth para detectar cercanía.'
            : state == BluetoothLowEnergyState.unauthorized
            ? 'Activa el permiso de dispositivos cercanos.'
            : state == BluetoothLowEnergyState.unsupported
            ? 'Este equipo no admite cercanía BLE.'
            : 'Preparando Bluetooth…',
      );
      return;
    }
    if (_running) return;
    _starting = true;
    _activationDone = Completer<void>();
    try {
      {
        final ids = trusted();
        if (ids.isEmpty) {
          _status('Vincula tu PC una vez para reconocerla al acercarte.');
          return;
        }
        // Windows cannot publish service UUID sections. Match our permitted
        // manufacturer payload after discovery instead of filtering by UUID.
        await _central!.startDiscovery();
        if (!_closed) _status('Buscando tus equipos por Bluetooth');
      }
      _running = true;
    } catch (error) {
      _running = false;
      if (!_closed) {
        _status(
          'No se pudo buscar por Bluetooth: $error. Comprueba Bluetooth y los permisos de Terax.',
        );
      }
    } finally {
      _starting = false;
      _activationDone!.complete();
    }
  }

  void _discovered(DiscoveredEventArgs event) {
    if (_closed) return;
    final id = trustedBeaconFingerprint(event.advertisement, trusted());
    if (id != null) {
      _lastSeen[id] = _now();
      final near = (_signals[id] ??= ProximityFilter()).update(event.rssi);
      if (near && _nearby != id) {
        _nearby = id;
        onNearby(id);
      } else if (!near && _nearby == id) {
        _nearby = null;
        onNearby(null);
      }
    }
  }

  Future<void> refreshPeers() async {
    if (_central == null || _closed) return;
    await _activationDone?.future;
    if (_closed) return;
    if (_running) {
      try {
        await _central!.stopDiscovery();
      } catch (_) {}
    }
    _running = false;
    await _activate();
  }

  Future<void> close() async {
    _closed = true;
    _expiry?.cancel();
    _windowsTimer?.cancel();
    await _stateSubscription?.cancel();
    await _scanSubscription?.cancel();
    await _activationDone?.future;
    try {
      if (_central != null && _running) await _central!.stopDiscovery();
    } catch (_) {}
    try {
      if (_windowsUsed) await _windows.invokeMethod<void>('stop');
    } catch (_) {}
  }
}

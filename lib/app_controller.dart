import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'transfer/protocol.dart';
import 'transfer/transport.dart';
import 'transfer/trust.dart';
import 'transfer/discovery.dart';
import 'transfer/proximity.dart';
import 'transfer/open_policy.dart';
import 'transfer/desktop_effects.dart';
import 'library/library_service.dart';
import 'ui/windows_notifications.dart';
import 'transfer/history_entry.dart';
import 'transfer/history_store.dart';
import 'sharing/shared_message.dart';
import 'sharing/transfer_sounds.dart';
export 'transfer/history_entry.dart';

enum SendState { idle, preparing, sending, complete, failed }

class AppController extends ChangeNotifier {
  AppController({
    DeviceVault? vault,
    TransferClient? client,
    Future<Directory> Function()? documentsDirectory,
    TransferHistoryStore? historyStore,
    TransferSounds? sounds,
  }) : _vault = vault ?? DeviceVault(PlatformSecrets()),
       _client = client ?? TransferClient(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _injectedHistoryStore = historyStore,
       sounds = sounds ?? TransferSounds();
  final TransferSounds sounds;
  Future<void> setTransferSounds(bool enabled) async {
    await sounds.setEnabled(enabled);
    _changed();
  }

  Future<void> _arrivalSound() async {
    if (!_disposed) await sounds.incoming();
  }

  final TransferHistoryStore? _injectedHistoryStore;
  late final TransferHistoryStore _historyStore =
      _injectedHistoryStore ??
      FileTransferHistoryStore(directory: _documentsDirectory);
  Future<void>? _historyLoading;
  SharedMessage? selectedMessage, receivedMessage;
  Future<void> loadHistory() => _historyLoading ??= _loadHistory();
  Future<void> _loadHistory() async {
    try {
      final saved = await _historyStore.load();
      if (!_disposed) {
        history.addAll(saved);
        history.sort((a, b) => b.time.compareTo(a.time));
        if (history.length > 50) history.removeRange(50, history.length);
        _changed();
      }
    } catch (_) {
      if (!_disposed) {
        notice = 'No se pudo cargar el historial.';
        _changed();
      }
    }
  }

  Future<void> _saveHistory() async {
    try {
      await loadHistory();
      await _historyStore.save(history);
    } catch (_) {
      if (!_disposed) {
        notice =
            'La transferencia terminó, pero no se pudo guardar el historial.';
        _changed();
      }
    }
  }

  Future<bool> clearHistory() async {
    await loadHistory();
    final previous = List<HistoryEntry>.of(history);
    history.clear();
    _changed();
    try {
      await _historyStore.save(history);
      return true;
    } catch (_) {
      if (!_disposed) {
        history.addAll(previous);
        history.sort((a, b) => b.time.compareTo(a.time));
        if (history.length > 50) history.removeRange(50, history.length);
        notice = 'No se pudo borrar el historial. Intenta de nuevo.';
        _changed();
      }
      return false;
    }
  }

  Future<LibraryItem> createMessage(SharedMessage message) async {
    final bytes = message.encode();
    final root = await _documentsDirectory();
    final folder = await Directory(
      p.join(root.path, 'Terax', 'Mensajes enviados'),
    ).create(recursive: true);
    final name =
        '${message.kind == SharedMessageKind.link ? 'Enlace' : 'Texto'}_${DateTime.now().microsecondsSinceEpoch}${SharedMessage.suffix}';
    final file = await File(
      p.join(folder.path, name),
    ).writeAsBytes(bytes, flush: true);
    return LibraryItem(
      id: file.path,
      name: name,
      isDirectory: false,
      isImage: false,
      size: bytes.length,
      modified: DateTime.now(),
      localFile: file,
    );
  }

  Future<void> _readReceivedMessage(ReceivedFile value) async {
    final message = await SharedMessage.read(value.file, name: value.name);
    if (_disposed ||
        !receiveComplete ||
        latestReceived?.file.path != value.file.path) {
      return;
    }
    receivedMessage = message;
    automaticOpenNotice = message == null
        ? 'No se pudo interpretar el mensaje. El archivo se conservó.'
        : null;
    _changed();
  }

  final DeviceVault _vault;
  final Future<Directory> Function() _documentsDirectory;
  TransferServer? server;
  final TransferClient _client;
  PairingInfo? peer;
  List<PairingInfo> knownPeers = [];
  bool peerOnline = false;
  bool _autoConnect = true;
  bool _initializing = false;
  bool resettingLinks = false;
  int _generation = 0;
  LanDiscovery? _discovery;
  BleProximity? _proximity;
  Timer? _reconnectTimer;
  Timer? _nearHeartbeat;
  DateTime? _remoteNearSeen;
  bool _relayingNear = false;
  final _probing = <String>{};
  final _lastSeen = <String, DateTime>{};
  Future<void> _saving = Future<void>.value();
  String proximityStatus = 'Cercanía Bluetooth opcional';
  String? nearbyFingerprint;
  List<String> addresses = [];
  String? address;
  File? selected;
  String? selectedName;
  String? outgoingId;
  DateTime? launchStarted;
  IncomingProgress? incomingVisual;
  ReceivedFile? latestReceived;
  bool receiveComplete = false, receiveCancelled = false;
  bool cancelRequested = false;
  String? incomingFailure, openingFailure, automaticOpenNotice;
  String? outgoingPeerName, incomingPeerName;
  String? get _singlePeerName {
    final peers = {
      for (final item in knownPeers) item.fingerprint: item.name,
      if (peer != null) peer!.fingerprint: peer!.name,
    };
    return peers.length == 1 ? peers.values.single : null;
  }

  // The current transport does not identify a sender per offer. A name is
  // unambiguous only when one device is linked; do not guess among several.
  String? get incomingSourceName => incomingPeerName ?? _singlePeerName;

  DateTime? autoOpenDue;
  Object? _autoOpenRequest;
  void cancelAutomaticOpen() {
    _autoOpenRequest = null;
    autoOpenDue = null;
    _changed();
  }

  Uint8List? outgoingPreview, incomingPreview;
  DateTime? incomingStarted;
  bool incomingAnimationReady = true;
  int selectedSize = 0;
  bool starting = true, connecting = false, picking = false;
  bool autoOpenImages = false;
  bool proximityWorking = false;
  bool desktopEffectsEnabled = true;
  DateTime? _lastDesktopWave;
  bool _disposed = false;
  SendState state = SendState.idle;
  double progress = 0;
  String? error, notice;
  IncomingProgress? incoming;
  final List<HistoryEntry> history = [];
  DateTime? startedSending;
  int _lastProgressUpdate = 0;
  bool get busy => state == SendState.preparing || state == SendState.sending;
  bool get canSend =>
      selected != null && peer != null && peerOnline && !busy && !connecting;
  PairingInfo? get ownPairing =>
      server == null || address == null ? null : server!.pairingFor(address!);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_initializing || server != null) return;
    final generation = _generation;
    _initializing = true;
    starting = true;
    error = null;
    _changed();
    try {
      final root = await _documentsDirectory();
      await loadHistory();
      await sounds.load();
      final stored = await _vault.loadIdentity();
      knownPeers = await _vault.loadPeers();
      autoOpenImages = await _vault.autoOpen();
      desktopEffectsEnabled = await _vault.desktopEffects();
      peer = knownPeers.firstOrNull;
      if (_disposed || generation != _generation) return;
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      addresses = interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .where((a) => isLocalAddress(a) && !a.startsWith('127.'))
          .toSet()
          .toList();
      address = addresses.firstOrNull;
      final service = TransferServer(
        directory: Directory(p.join(root.path, 'Terax', 'Recibidos')),
        identity: stored.identity,
        token: stored.token,
        onProximity: (fingerprint, near) {
          if (_disposed ||
              generation != _generation ||
              !knownPeers.any((p) => p.fingerprint == fingerprint)) {
            return;
          }
          if (near) {
            _remoteNearSeen = DateTime.now();
            nearbyFingerprint = fingerprint;
          } else if (nearbyFingerprint == fingerprint) {
            nearbyFingerprint = null;
            _remoteNearSeen = null;
          }
          _changed();
        },
        onOffered: (offer) {
          incomingPeerName = _singlePeerName;
          receivedMessage = null;
          incomingAnimationReady = !Platform.isWindows;
          if (Platform.isWindows) unawaited(_presentIncoming(offer.id));
          latestReceived = null;
          incomingFailure = null;
          openingFailure = null;
          automaticOpenNotice = null;
          _autoOpenRequest = null;
          autoOpenDue = null;
          receiveComplete = false;
          receiveCancelled = false;
          incomingStarted = DateTime.now();
          incomingPreview = null;
          incomingVisual = IncomingProgress(
            offer.name,
            0,
            offer.size,
            id: offer.id,
            stage: IncomingStage.preparing,
          );
          if (offer.preview != null) unawaited(_acceptPreview(offer));
          _changed();
        },
        onPaired: (remote) async {
          if (_disposed || generation != _generation) {
            throw const TransferException('El vínculo ya no es válido.');
          }
          await _remember(remote, generation: generation);
          if (_disposed || generation != _generation) {
            throw const TransferException('El vínculo ya no es válido.');
          }
          peer = remote;
          peerOnline = true;
          _autoConnect = true;
          _lastSeen[remote.fingerprint] = DateTime.now();
          notice = '${remote.name} autorizado. Se conectará automáticamente.';
          _discovery?.search();
          await _proximity?.refreshPeers();
          _changed();
        },
        name: Platform.isWindows ? Platform.localHostname : 'Android · Terax',
        onProgress: (value) {
          final previous = incoming;
          incoming = value;
          if (value != null) {
            if (previous == null && value.stage != IncomingStage.preparing) {
              latestReceived = null;
              incomingFailure = null;
              openingFailure = null;
              automaticOpenNotice = null;
              _autoOpenRequest = null;
              autoOpenDue = null;
              receiveComplete = false;
              receiveCancelled = false;
              incomingStarted = DateTime.now();
            }
            incomingVisual = value;
          } else if (!receiveComplete && incomingVisual != null) {
            // The server clears this stage without onReceived only when its
            // byte count/hash check failed. Other failures report onError.
            if (previous?.stage == IncomingStage.verifying &&
                incomingFailure == null) {
              incomingFailure =
                  'El archivo no pasó la verificación de integridad.';
            }
            receiveCancelled = incomingFailure == null;
          }
          _changed();
        },
        onError: (value) {
          if (incoming != null && !receiveComplete) incomingFailure = value;
          error = value;
          _changed();
        },
        onReceived: (received) {
          unawaited(_arrivalSound());
          latestReceived = received;
          receiveComplete = true;
          receiveCancelled = false;
          history.insert(
            0,
            HistoryEntry(
              name: received.name,
              size: received.size,
              incoming: true,
              file: received.file,
              time: DateTime.now(),
            ),
          );
          if (history.length > 50) history.removeLast();
          unawaited(_saveHistory());
          if (Platform.isWindows) {
            unawaited(
              WindowsNotifications.received(
                SharedMessage.displayName(received.name),
              ),
            );
          }
          notice = '${received.name} recibido y verificado';
          _changed();
          if (SharedMessage.matchesName(received.name)) {
            unawaited(_readReceivedMessage(received));
          } else if (autoOpenImages && Platform.isWindows) {
            unawaited(prepareAutomaticOpening());
          }
        },
      );
      try {
        await service.start(port: 44662);
      } on SocketException {
        await service.start();
      }
      if (_disposed) {
        await service.close();
        return;
      }
      server = service;
      _discovery = LanDiscovery(
        own: () => service.pairingFor(address ?? '127.0.0.1'),
        peers: () => knownPeers,
        onFound: (found) => unawaited(_reconnect(found)),
      );
      try {
        await _discovery!.start();
      } on SocketException {
        /* Direct reconnect remains available if UDP is blocked. */
      }
      _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_disposed) return;
        if (_remoteNearSeen != null &&
            DateTime.now().difference(_remoteNearSeen!).inSeconds > 10) {
          _remoteNearSeen = null;
          nearbyFingerprint = null;
          _changed();
        }
        if (peer != null &&
            DateTime.now()
                    .difference(
                      _lastSeen[peer!.fingerprint] ??
                          DateTime.fromMillisecondsSinceEpoch(0),
                    )
                    .inSeconds >
                15) {
          peerOnline = false;
          _changed();
        }
        if (_autoConnect && !busy) {
          for (final known in knownPeers) {
            unawaited(_reconnect(known));
          }
        }
      });
      for (final known in knownPeers) {
        unawaited(_reconnect(known));
      }
      if (Platform.isWindows || await _vault.proximityEnabled()) {
        await enableProximity(requestPermission: false);
      }
    } catch (_) {
      error =
          'No se pudo iniciar la recepción. Revisa la red y vuelve a intentar.';
    } finally {
      _initializing = false;
      starting = false;
      _changed();
    }
  }

  Future<void> refreshNetwork() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      addresses = interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .where((a) => isLocalAddress(a) && !a.startsWith('127.'))
          .toSet()
          .toList();
      if (!addresses.contains(address)) address = addresses.firstOrNull;
      _changed();
    } catch (_) {
      error = 'No se pudo actualizar la red.';
      _changed();
    }
  }

  void chooseAddress(String value) {
    address = value;
    _changed();
  }

  void setAccepting(bool value) {
    server?.accepting = value;
    _changed();
  }

  void setAutoOpen(bool value) {
    autoOpenImages = value;
    if (!value) {
      _autoOpenRequest = null;
      autoOpenDue = null;
    }
    unawaited(
      _vault.saveAutoOpen(value).catchError((_) {
        error = 'No se pudo guardar la preferencia de apertura.';
        _changed();
      }),
    );
    _changed();
  }

  void clearMessage() {
    error = null;
    notice = null;
    _changed();
  }

  void disconnect() {
    if (!busy) {
      peer = null;
      peerOnline = false;
      _autoConnect = false;
      _changed();
    }
  }

  Future<bool> connect(String code) async {
    if (connecting || busy || resettingLinks) return false;
    final generation = _generation;
    connecting = true;
    error = null;
    _changed();
    try {
      final target = PairingInfo.parse(code);
      if (target.token == ownPairing?.token) {
        throw const TransferException('Este código es de tu propio equipo.');
      }
      await _client.probe(target);
      if (_disposed || generation != _generation) return false;
      final own = ownPairing;
      if (own != null) await _client.pair(target, own);
      await _remember(target, generation: generation);
      if (_disposed || generation != _generation) return false;
      peer = target;
      peerOnline = true;
      _autoConnect = true;
      _lastSeen[target.fingerprint] = DateTime.now();
      notice = '${target.name} guardado. La próxima conexión será automática.';
      _discovery?.search();
      await _proximity?.refreshPeers();
      return true;
    } catch (e) {
      error = e is FormatException
          ? e.message.toString()
          : e is TransferException
          ? e.message
          : 'No se pudo conectar. Revisa que ambos estén en la misma red y que el código siga vigente.';
      return false;
    } finally {
      connecting = false;
      _changed();
    }
  }

  Future<void> _remember(PairingInfo target, {int? generation}) {
    final expectedGeneration = generation ?? _generation;
    final nextSave = _saving.catchError((_) {}).then((_) async {
      if (expectedGeneration != _generation || _disposed) return;
      final next = [
        target,
        ...knownPeers.where((p) => p.fingerprint != target.fingerprint),
      ].take(16).toList();
      await _vault.savePeers(next);
      knownPeers = next;
    });
    _saving = nextSave;
    return nextSave;
  }

  Future<void> resetLinks() async {
    if (busy ||
        incoming != null ||
        _initializing ||
        resettingLinks ||
        connecting) {
      return;
    }
    resettingLinks = true;
    _autoOpenRequest = null;
    autoOpenDue = null;
    _generation++;
    _autoConnect = false;
    peerOnline = false;
    starting = true;
    _changed();
    try {
      _reconnectTimer?.cancel();
      _nearHeartbeat?.cancel();
      _remoteNearSeen = null;
      await _discovery?.close();
      await _proximity?.close();
      await server?.close();
      await _saving.catchError((_) {});
      await _vault.resetLinks();
      server = null;
      _discovery = null;
      _proximity = null;
      peer = null;
      peerOnline = false;
      nearbyFingerprint = null;
      knownPeers = [];
      _autoConnect = true;
      _lastSeen.clear();
      await initialize();
      notice =
          'Vínculos restablecidos. Los códigos anteriores ya no autorizan este equipo.';
    } catch (_) {
      error =
          'No se pudieron restablecer los vínculos. Cierra y abre Terax para reintentar.';
    } finally {
      resettingLinks = false;
      starting = false;
      _changed();
    }
  }

  Future<void> _reconnect(PairingInfo target) async {
    if (_disposed ||
        !_autoConnect ||
        busy ||
        connecting ||
        _probing.contains(target.fingerprint)) {
      return;
    }
    _probing.add(target.fingerprint);
    final generation = _generation;
    try {
      await _client.probe(target);
      if (_disposed || !_autoConnect || generation != _generation) return;
      _lastSeen[target.fingerprint] = DateTime.now();
      if (peer == null ||
          peer!.fingerprint == target.fingerprint ||
          nearbyFingerprint == target.fingerprint) {
        peer = target;
        peerOnline = true;
        _changed();
      }
      final known = knownPeers
          .where((p) => p.fingerprint == target.fingerprint)
          .firstOrNull;
      if (known != null &&
          (known.host != target.host || known.port != target.port)) {
        await _remember(target, generation: generation);
      }
    } catch (_) {
      /* An offline known device is ordinary; keep looking silently. */
    } finally {
      _probing.remove(target.fingerprint);
    }
  }

  Future<void> enableProximity({bool requestPermission = true}) async {
    if (_disposed || proximityWorking) return;
    if (server == null) {
      proximityStatus = 'Primero inicia la conexión segura de Terax.';
      _changed();
      return;
    }
    proximityWorking = true;
    proximityStatus = requestPermission
        ? 'Comprobando Bluetooth y permisos…'
        : 'Comprobando Bluetooth…';
    _changed();
    try {
      _proximity ??= BleProximity(
        fingerprint: server!.identity.fingerprint,
        trusted: () => knownPeers.map((p) => p.fingerprint).toList(),
        onStatus: (value) {
          if (proximityStatus == value) return;
          proximityStatus = value;
          _changed();
        },
        onNearby: (value) {
          final previous = nearbyFingerprint;
          nearbyFingerprint = value;
          if (Platform.isAndroid) {
            _nearHeartbeat?.cancel();
            if (previous != null && previous != value) {
              unawaited(_relayProximity(previous, false));
            }
            if (value != null) {
              unawaited(_relayProximity(value, true));
              _nearHeartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
                if (!_disposed && nearbyFingerprint == value) {
                  unawaited(_relayProximity(value, true));
                }
              });
            }
          }
          if (value != null) {
            final known = knownPeers
                .where((p) => p.fingerprint == value)
                .firstOrNull;
            if (known != null) unawaited(_reconnect(known));
            _discovery?.search();
          }
          _changed();
        },
      );
      await _proximity!.start(requestPermission: requestPermission);
      if (requestPermission && _proximity!.ready) {
        try {
          await _vault.saveProximity(true);
        } catch (_) {
          /* Retry next launch if settings storage fails. */
        }
      }
    } finally {
      proximityWorking = false;
      _changed();
    }
  }

  Future<void> resumeProximity() async {
    if (_disposed || proximityWorking || server == null || _proximity == null) {
      return;
    }
    await enableProximity(requestPermission: false);
  }

  Future<void> openProximitySettings() async {
    try {
      if (_proximity == null) await enableProximity(requestPermission: false);
      await _proximity?.openAppSettings();
    } catch (_) {
      proximityStatus =
          'Abre Ajustes de Android → Aplicaciones → Terax → Permisos.';
      _changed();
    }
  }

  Future<void> setDesktopEffects(bool enabled) async {
    desktopEffectsEnabled = enabled;
    _changed();
    try {
      if (!enabled && Platform.isWindows) await const DesktopEffects().stop();
      await _vault.saveDesktopEffects(enabled);
    } catch (_) {
      notice = 'No se pudo guardar la preferencia del efecto.';
      _changed();
    }
  }

  Future<bool> showDesktopWave({bool force = false}) async {
    if (ServicesBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      return false;
    }
    if (!Platform.isWindows || !desktopEffectsEnabled || _disposed) {
      return false;
    }
    if (!force &&
        _lastDesktopWave != null &&
        DateTime.now().difference(_lastDesktopWave!).inSeconds < 15) {
      return false;
    }
    _lastDesktopWave = DateTime.now();
    try {
      return await const DesktopEffects()
          .play(
            reducedMotion: ServicesBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations,
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      notice =
          'No se pudo mostrar el efecto de escritorio. La recepción sigue disponible.';
      _changed();
      return false;
    }
  }

  Future<void> _relayProximity(String targetFingerprint, bool near) async {
    if (_disposed || _relayingNear || server == null) return;
    final target = knownPeers
        .where((p) => p.fingerprint == targetFingerprint)
        .firstOrNull;
    if (target == null) return;
    _relayingNear = true;
    try {
      await _client.nearby(target, server!.identity.fingerprint, near);
    } catch (_) {
      /* Discovery/HTTPS will retry; proximity alone never authorizes a transfer. */
    } finally {
      _relayingNear = false;
    }
  }

  Future<void> pickFile() async {
    if (busy || picking) return;
    picking = true;
    error = null;
    _changed();
    try {
      final result = await FilePicker.pickFile();
      if (result == null || _disposed) return;
      final path = result.path;
      if (path == null) {
        throw const TransferException(
          'No se pudo leer ese archivo. Guárdalo en el teléfono e intenta de nuevo.',
        );
      }
      final file = File(path);
      final size = await file.length();
      if (size > maxFileBytes) {
        throw const TransferException('Selecciona un archivo de hasta 1 GiB.');
      }
      selected = file;
      selectedName = p.basename(file.path);
      selectedSize = size;
      state = SendState.idle;
      progress = 0;
    } catch (e) {
      error = e is TransferException
          ? e.message
          : 'No se pudo seleccionar el archivo.';
    } finally {
      picking = false;
      _changed();
    }
  }

  Future<void> send() async {
    if (!canSend) return;
    final file = selected!;
    final destination = peer!;
    outgoingPeerName = destination.name;
    cancelRequested = false;
    state = SendState.preparing;
    progress = 0;
    error = null;
    notice = null;
    startedSending = DateTime.now();
    _changed();
    try {
      await _client.send(
        file,
        destination,
        name: selectedName,
        preview: outgoingPreview == null
            ? null
            : base64.encode(outgoingPreview!),
        onReady: (offer) {
          unawaited(sounds.outgoing());
          outgoingId = offer.id;
          launchStarted = DateTime.now();
          _changed();
        },
        onProgress: (value) {
          state = SendState.sending;
          progress = value;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastProgressUpdate > 80 || value == 1) {
            _lastProgressUpdate = now;
            _changed();
          }
        },
      );
      // Give the launch gesture time to finish even for tiny local transfers.
      // Progress reaches 100% only after the receiver has confirmed integrity.
      final remaining =
          1900 -
          DateTime.now()
              .difference(launchStarted ?? startedSending!)
              .inMilliseconds;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining));
      }
      state = SendState.complete;
      history.insert(
        0,
        HistoryEntry(
          name: selectedName ?? p.basename(file.path),
          size: selectedSize,
          incoming: false,
          file: file,
          time: DateTime.now(),
        ),
      );
      if (history.length > 50) history.removeLast();
      unawaited(_saveHistory());
      notice = 'El archivo llegó a ${destination.name}';
    } catch (e) {
      state = SendState.failed;
      error = cancelRequested
          ? 'Envío cancelado.'
          : e is TransferException
          ? e.message
          : 'Se interrumpió el envío. Revisa la conexión e intenta de nuevo.';
    }
    _changed();
  }

  void cancel() {
    if (!busy || progress >= 1) return;
    cancelRequested = true;
    _client.cancel();
    _changed();
  }

  Future<void> selectLibraryItem(LibraryItem item) async {
    if (busy || picking || item.isDirectory) return;
    picking = true;
    error = null;
    outgoingPeerName = null;
    selectedMessage = null;
    // A new selection owns its own presentation, even if resolution fails.
    state = SendState.idle;
    progress = 0;
    outgoingId = null;
    launchStarted = null;
    cancelRequested = false;
    selected = null;
    selectedName = null;
    selectedSize = 0;
    outgoingPreview = null;
    _changed();
    try {
      final file = await item.resolve();
      if (_disposed) return;
      selected = file;
      selectedName = item.name;
      selectedSize = await file.length();
      outgoingPreview = await _makePreview(file, item.isImage);
      selectedMessage = await SharedMessage.read(file, name: item.name);
      state = SendState.idle;
      progress = 0;
      outgoingId = null;
      launchStarted = null;
    } catch (e) {
      error = e is FileSystemException
          ? 'El archivo ya no existe o no se puede leer. Actualiza la biblioteca.'
          : e.toString().replaceFirst('Bad state: ', '');
    } finally {
      picking = false;
      _changed();
    }
  }

  Future<void> sendLibraryItem(LibraryItem item) async {
    if (busy || picking) return;
    if (peer == null || !peerOnline) {
      error = 'Conecta tu otro equipo para enviar.';
      _changed();
      return;
    }
    await selectLibraryItem(item);
    if (error == null) await send();
  }

  void dismissTransfer({bool outgoing = true, bool received = true}) {
    if (outgoing && busy || received && incoming != null) return;
    if (outgoing) {
      outgoingPeerName = null;
      state = SendState.idle;
      outgoingId = null;
      launchStarted = null;
      cancelRequested = false;
    }
    if (received) {
      incomingPeerName = null;
      receivedMessage = null;
      incomingVisual = null;
      latestReceived = null;
      incomingPreview = null;
      receiveComplete = false;
      receiveCancelled = false;
      incomingFailure = null;
      openingFailure = null;
      automaticOpenNotice = null;
      _autoOpenRequest = null;
      autoOpenDue = null;
    }
    _changed();
  }

  Future<Uint8List?> _makePreview(File file, bool image) async {
    if (!image) return null;
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width <= 0 ||
            descriptor.height <= 0 ||
            descriptor.width * descriptor.height > 100000000) {
          return null;
        }
        final codec = await descriptor.instantiateCodec(targetWidth: 120);
        try {
          final frame = await codec.getNextFrame();
          try {
            final bytes = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (bytes == null || bytes.lengthInBytes > 24576) return null;
            return bytes.buffer.asUint8List();
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _acceptPreview(TransferOffer offer) async {
    try {
      final bytes = base64.decode(offer.preview!);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width <= 0 ||
            descriptor.height <= 0 ||
            descriptor.width > 512 ||
            descriptor.height > 512) {
          return;
        }
        if (!_disposed && incomingVisual?.id == offer.id) {
          incomingPreview = bytes;
          _changed();
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
    } catch (_) {
      /* A preview never determines whether the actual file is accepted. */
    }
  }

  Future<void> openFile(File file) async {
    if (latestReceived?.file.path == file.path) {
      openingFailure = null;
      if (error?.contains('abrir el archivo') == true) error = null;
      _changed();
    }
    try {
      if (Platform.isWindows) {
        final opened = await const MethodChannel(
          'terax/files',
        ).invokeMethod<bool>('open', file.path);
        if (opened != true) {
          throw const TransferException(
            'No hay una aplicación para abrir este archivo.',
          );
        }
        return;
      }
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        error =
            'No se pudo abrir el archivo. Comprueba que tienes una aplicación compatible.';
        if (latestReceived?.file.path == file.path) openingFailure = error;
        _changed();
      }
    } catch (_) {
      error = 'No se pudo abrir el archivo.';
      if (latestReceived?.file.path == file.path) {
        openingFailure =
            'Se guardó, pero no se pudo abrir. Comprueba que tienes una aplicación compatible.';
      }
      _changed();
    }
  }

  Future<void> _presentIncoming(String id) async {
    try {
      await const DesktopEffects().stop();
      await const MethodChannel('terax/files')
          .invokeMethod<void>('presentIncoming')
          .timeout(const Duration(milliseconds: 600));
    } catch (_) {
      // Still show the receipt when foreground activation is unavailable.
    }
    if (_disposed || incomingVisual?.id != id) return;
    incomingAnimationReady = true;
    incomingStarted = DateTime.now();
    _changed();
  }

  Future<void> openFolder() async {
    if (server == null || !Platform.isWindows) return;
    try {
      await Process.run('explorer.exe', [server!.directory.path]);
    } catch (_) {
      error = 'No se pudo abrir la carpeta de recibidos.';
      _changed();
    }
  }

  Future<void> prepareAutomaticOpening() async {
    final received = latestReceived;
    if (_disposed || !receiveComplete || received == null || !autoOpenImages) {
      return;
    }
    final request = Object();
    _autoOpenRequest = request;
    final kind = autoOpenKind(received.name);
    automaticOpenNotice = null;
    openingFailure = null;
    bool current() =>
        !_disposed &&
        identical(_autoOpenRequest, request) &&
        autoOpenImages &&
        receiveComplete &&
        latestReceived?.file.path == received.file.path;
    void skip() {
      if (current()) {
        automaticOpenNotice = 'Este archivo no se abre automáticamente.';
        _autoOpenRequest = null;
        autoOpenDue = null;
        _changed();
      }
    }

    try {
      if (kind == AutoOpenKind.none) {
        skip();
        return;
      }
      if (kind == AutoOpenKind.document) {
        if (received.size > 64 * 1024 * 1024) {
          skip();
          return;
        }
        final handle = await received.file.open();
        late List<int> bytes;
        try {
          bytes = await handle.read(1024);
        } finally {
          await handle.close();
        }
        if (!validDocumentHeader(received.name, bytes)) {
          skip();
          return;
        }
      } else {
        if (received.size > 32 * 1024 * 1024) {
          skip();
          return;
        }
        final buffer = await ui.ImmutableBuffer.fromFilePath(
          received.file.path,
        );
        ui.ImageDescriptor? descriptor;
        try {
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          if (descriptor.width <= 0 ||
              descriptor.height <= 0 ||
              descriptor.width * descriptor.height > 40000000) {
            skip();
            return;
          }
          final codec = await descriptor.instantiateCodec(
            targetWidth: 1,
            targetHeight: 1,
          );
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor?.dispose();
          buffer.dispose();
        }
      }
      if (!current()) return;
      autoOpenDue = DateTime.now().add(const Duration(milliseconds: 1200));
      _changed();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!current()) return;
      autoOpenDue = null;
      _autoOpenRequest = null;
      _changed();
      await openFile(received.file);
      _changed();
    } catch (_) {
      skip();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autoOpenRequest = null;
    autoOpenDue = null;
    _reconnectTimer?.cancel();
    _nearHeartbeat?.cancel();
    unawaited(_discovery?.close());
    unawaited(_proximity?.close());
    _client.cancel();
    sounds.dispose();
    unawaited(server?.close());
    super.dispose();
  }
}

String formatBytes(num bytes) {
  if (bytes < 1024) return '${bytes.round()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

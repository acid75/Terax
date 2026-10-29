// Public callback names keep callers independent of implementation details.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../library/library_service.dart';

enum TransferJobState { pending, sending, sent, failed, cancelled }

@immutable
class TransferQueueJob {
  const TransferQueueJob({
    required this.id,
    required this.item,
    this.state = TransferJobState.pending,
    this.error,
  });
  final String id;
  final LibraryItem item;
  final TransferJobState state;
  final String? error;
}

@immutable
class QueueOutcome {
  const QueueOutcome.sent() : verified = true, cancelled = false, error = null;
  const QueueOutcome.failed(String message)
    : verified = false,
      cancelled = false,
      error = message;
  const QueueOutcome.cancelled()
    : verified = false,
      cancelled = true,
      error = null;
  final bool verified;
  final bool cancelled;
  final String? error;
}

/// Foreground-only serial orchestration. The sender owns integrity verification.
class TransferQueue extends ChangeNotifier {
  TransferQueue({
    required Future<QueueOutcome> Function(LibraryItem) send,
    required bool Function() canStart,
    required void Function() cancelCurrent,
  }) : _send = send,
       _canStart = canStart,
       _cancelCurrent = cancelCurrent;

  final Future<QueueOutcome> Function(LibraryItem) _send;
  final bool Function() _canStart;
  final void Function() _cancelCurrent;
  final List<TransferQueueJob> _jobs = [];
  int _nextId = 0;
  bool _running = false, _paused = false, _disposed = false;
  Future<void>? _activeRun;
  List<TransferQueueJob> get jobs => List.unmodifiable(_jobs);
  bool get running => _running;
  bool get paused => _paused;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _replace(int index, TransferJobState state, [String? error]) {
    final old = _jobs[index];
    _jobs[index] = TransferQueueJob(
      id: old.id,
      item: old.item,
      state: state,
      error: error,
    );
  }

  void add(List<LibraryItem> items) {
    if (_disposed) return;
    final ids = _jobs
        .where(
          (j) =>
              j.state == TransferJobState.pending ||
              j.state == TransferJobState.sending,
        )
        .map((j) => j.item.id)
        .toSet();
    final additions = <LibraryItem>[];
    for (final item in items) {
      if (!item.isDirectory && ids.add(item.id)) additions.add(item);
    }
    if (_jobs.length + additions.length > 100) {
      throw StateError(
        'La cola admite hasta 100 archivos. Borra los finalizados para agregar más.',
      );
    }
    for (final item in additions) {
      _jobs.add(TransferQueueJob(id: 'queue-${_nextId++}', item: item));
    }
    if (additions.isNotEmpty) _notify();
  }

  Future<void> start() {
    if (_disposed) return Future.value();
    if (_running) return _activeRun!;
    if (_jobs.any((j) => j.state == TransferJobState.failed)) {
      return Future.value();
    }
    final completion = Completer<void>();
    _activeRun = completion.future;
    _running = true;
    _paused = false;
    _notify();
    _run().then(completion.complete, onError: completion.completeError);
    return completion.future;
  }

  Future<void> _run() async {
    try {
      while (!_disposed && !_paused) {
        final index = _jobs.indexWhere(
          (j) => j.state == TransferJobState.pending,
        );
        if (index < 0) break;
        if (!_canStart()) {
          _paused = true;
          break;
        }
        final job = _jobs[index];
        _replace(index, TransferJobState.sending);
        _notify();
        if (_disposed) break;
        QueueOutcome result;
        try {
          result = await _send(job.item);
        } catch (error) {
          result = QueueOutcome.failed(error.toString());
        }
        if (_disposed) break;
        final current = _jobs.indexWhere((j) => j.id == job.id);
        if (result.verified) {
          _replace(current, TransferJobState.sent);
        } else if (result.cancelled) {
          _replace(current, TransferJobState.cancelled);
          _paused = true;
        } else {
          _replace(
            current,
            TransferJobState.failed,
            result.error ?? 'No se pudo verificar el archivo.',
          );
          _paused = true;
        }
        _notify();
      }
    } finally {
      _running = false;
      _notify();
    }
  }

  void pause() {
    if (!_disposed) {
      _paused = true;
      _notify();
    }
  }

  void cancelAll() {
    if (_disposed) return;
    _paused = true;
    final active = _jobs.any((j) => j.state == TransferJobState.sending);
    for (var i = 0; i < _jobs.length; i++) {
      if (_jobs[i].state == TransferJobState.pending) {
        _replace(i, TransferJobState.cancelled);
      }
    }
    _notify();
    if (active) _cancelCurrent();
  }

  Future<void> retry(String id) {
    if (_disposed || _running) return Future.value();
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index < 0 || _jobs[index].state != TransferJobState.failed) {
      return Future.value();
    }
    _replace(index, TransferJobState.pending);
    return start();
  }

  void remove(String id) {
    if (_disposed) return;
    _jobs.removeWhere((j) => j.id == id && j.state != TransferJobState.sending);
    _notify();
  }

  void clearFinished() {
    if (_disposed) return;
    _jobs.removeWhere(
      (j) =>
          j.state == TransferJobState.sent ||
          j.state == TransferJobState.cancelled,
    );
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _paused = true;
    super.dispose();
  }
}

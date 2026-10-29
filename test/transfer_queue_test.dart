import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/transfer/transfer_queue.dart';

LibraryItem item(String id, {bool directory = false}) => LibraryItem(
  id: id,
  name: id,
  isDirectory: directory,
  isImage: false,
  size: 1,
  modified: DateTime(2026),
);

void main() {
  late List<String> calls;
  late List<Completer<QueueOutcome>> gates;
  late TransferQueue queue;
  late bool ready;
  late int cancellations;
  setUp(() {
    calls = [];
    gates = [];
    ready = true;
    cancellations = 0;
    queue = TransferQueue(
      send: (file) {
        calls.add(file.id);
        final gate = Completer<QueueOutcome>();
        gates.add(gate);
        return gate.future;
      },
      canStart: () => ready,
      cancelCurrent: () => cancellations++,
    );
  });
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test(
    'serial, reentrant start, verified completion and deduplication',
    () async {
      queue.add([
        item('a'),
        item('a'),
        item('folder', directory: true),
        item('b'),
      ]);
      final run = queue.start();
      expect(identical(run, queue.start()), isTrue);
      expect(calls, ['a']);
      expect(queue.jobs.first.state, TransferJobState.sending);
      gates[0].complete(const QueueOutcome.sent());
      await tick();
      expect(calls, ['a', 'b']);
      expect(queue.jobs.first.state, TransferJobState.sent);
      gates[1].complete(const QueueOutcome.sent());
      await run;
      queue.add([item('a')]);
      expect(queue.jobs.length, 3);
      expect(() => queue.jobs.clear(), throwsUnsupportedError);
    },
  );

  test('failure retains pending and retry preserves order', () async {
    queue.add([item('a'), item('b')]);
    final run = queue.start();
    gates[0].complete(const QueueOutcome.failed('Integridad incorrecta'));
    await run;
    expect(queue.jobs[0].error, 'Integridad incorrecta');
    expect(queue.jobs[1].state, TransferJobState.pending);
    await queue.start();
    expect(calls, ['a']);
    final retry = queue.retry(queue.jobs.first.id);
    gates[1].complete(const QueueOutcome.sent());
    await tick();
    expect(calls, ['a', 'a', 'b']);
    gates[2].complete(const QueueOutcome.sent());
    await retry;
    expect(queue.jobs.every((j) => j.state == TransferJobState.sent), isTrue);
  });

  test('pause lets active file finish, resume sends pending', () async {
    queue.add([item('a'), item('b')]);
    final run = queue.start();
    queue.pause();
    gates[0].complete(const QueueOutcome.sent());
    await run;
    expect(calls, ['a']);
    expect(queue.paused, isTrue);
    final resumed = queue.start();
    gates[1].complete(const QueueOutcome.sent());
    await resumed;
    expect(calls, ['a', 'b']);
  });

  test('lost readiness pauses without failing next file', () async {
    queue.add([item('a'), item('b')]);
    final run = queue.start();
    ready = false;
    gates[0].complete(const QueueOutcome.sent());
    await run;
    expect(queue.paused, isTrue);
    expect(queue.jobs[1].state, TransferJobState.pending);
    ready = true;
    final resumed = queue.start();
    gates[1].complete(const QueueOutcome.sent());
    await resumed;
  });

  test(
    'cancel requests active cancellation and verified result wins race',
    () async {
      queue.add([item('a'), item('b')]);
      final run = queue.start();
      queue.cancelAll();
      expect(cancellations, 1);
      expect(queue.jobs.first.state, TransferJobState.sending);
      expect(queue.jobs.last.state, TransferJobState.cancelled);
      gates[0].complete(const QueueOutcome.sent());
      await run;
      expect(queue.jobs.first.state, TransferJobState.sent);
      expect(calls, ['a']);
    },
  );

  test('actual cancellation never claims success', () async {
    queue.add([item('a')]);
    final run = queue.start();
    queue.cancelAll();
    gates[0].complete(const QueueOutcome.cancelled());
    await run;
    expect(queue.jobs.single.state, TransferJobState.cancelled);
  });

  test('exceptions fail and stop', () async {
    queue.add([item('a'), item('b')]);
    final run = queue.start();
    gates[0].completeError(StateError('archivo eliminado'));
    await run;
    expect(queue.jobs.first.state, TransferJobState.failed);
    expect(queue.jobs.first.error, contains('archivo eliminado'));
    expect(calls, ['a']);
  });

  test(
    'dispose ignores active completion and never starts later file',
    () async {
      queue.add([item('a'), item('b')]);
      final run = queue.start();
      var notifications = 0;
      queue.addListener(() => notifications++);
      queue.dispose();
      gates[0].complete(const QueueOutcome.sent());
      await run;
      expect(calls, ['a']);
      expect(notifications, 0);
      expect(queue.running, isFalse);
    },
  );

  test('capacity rejection is atomic and explicit', () {
    queue.add(List.generate(100, (i) => item('$i')));
    expect(() => queue.add([item('extra')]), throwsStateError);
    expect(queue.jobs.length, 100);
  });
}

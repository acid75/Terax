// The first argument is a file containing a pairing code. Keep codes out of logs.
import 'dart:io';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Uso: dart run tools/send_test_file.dart <archivo-codigo> <archivo-enviar>',
    );
    exitCode = 64;
    return;
  }
  final peer = PairingInfo.parse(await File(args[0]).readAsString());
  await TransferClient().send(File(args[1]), peer);
  stdout.writeln('Archivo recibido y verificado por Terax.');
}

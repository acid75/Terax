import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

class ServerIdentity {
  const ServerIdentity(this.certificate, this.privateKey, this.fingerprint);
  final String certificate, privateKey, fingerprint;

  static Future<ServerIdentity> generate() => Isolate.run(() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final key = pair.privateKey as RSAPrivateKey;
    final csr = X509Utils.generateRsaCsrPem(
      {'CN': 'Terax local'},
      key,
      pair.publicKey as RSAPublicKey,
    );
    final cert = X509Utils.generateSelfSignedCertificate(key, csr, 3650);
    final der = base64.decode(
      cert.replaceAll(RegExp(r'-----[^-]+-----|\s'), ''),
    );
    return ServerIdentity(
      cert,
      CryptoUtils.encodeRSAPrivateKeyToPem(key),
      sha256.convert(der).toString(),
    );
  });

  SecurityContext context() => SecurityContext()
    ..useCertificateChainBytes(utf8.encode(certificate))
    ..usePrivateKeyBytes(utf8.encode(privateKey));
}

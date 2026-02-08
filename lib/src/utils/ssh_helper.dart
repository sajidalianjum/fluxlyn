import 'package:dartssh2/dartssh2.dart';

List<SSHKeyPair> decryptSSHKeyPairs(List<String> args) {
  final keyContent = args[0];
  final password = args[1].isEmpty ? null : args[1];
  return SSHKeyPair.fromPem(keyContent, password);
}

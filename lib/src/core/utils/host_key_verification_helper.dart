import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/host_key_verification_service.dart';
import '../../features/connections/presentation/dialogs/host_key_dialog.dart';

class HostKeyVerificationHelper {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<bool> verifyHostKey(
    HostKeyVerificationService verificationService,
    String host,
    int port,
    String keyType,
    Uint8List fingerprint,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return false;
    }

    final result = verificationService.verify(host, port, keyType, fingerprint);
    final info = verificationService.getVerificationInfo(
      host,
      port,
      keyType,
      fingerprint,
    );

    switch (result) {
      case HostKeyVerificationResult.trusted:
        return true;

      case HostKeyVerificationResult.unknown:
        final userAccepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => HostKeyDialog(
            info: info,
            type: HostKeyDialogType.newHost,
            onTrust: () {
              Navigator.pop(context, true);
            },
            onReject: () {
              Navigator.pop(context, false);
            },
          ),
        );

        if (userAccepted == true) {
          await verificationService.trustHost(host, port, keyType, fingerprint);
        }
        return userAccepted == true;

      case HostKeyVerificationResult.mismatch:
        final userAccepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => HostKeyDialog(
            info: info,
            type: HostKeyDialogType.keyMismatch,
            onTrust: () {
              Navigator.pop(context, true);
            },
            onReject: () {
              Navigator.pop(context, false);
            },
          ),
        );

        if (userAccepted == true) {
          await verificationService.trustHost(host, port, keyType, fingerprint);
        }
        return userAccepted == true;
    }
  }
}
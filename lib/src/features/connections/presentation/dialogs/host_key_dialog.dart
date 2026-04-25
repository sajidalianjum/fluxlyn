import 'package:flutter/material.dart';
import '../../../../core/services/host_key_verification_service.dart';

enum HostKeyDialogType {
  newHost,
  keyMismatch,
}

class HostKeyDialog extends StatelessWidget {
  final HostKeyVerificationInfo info;
  final HostKeyDialogType type;
  final VoidCallback onTrust;
  final VoidCallback onReject;

  HostKeyDialog({
    super.key,
    required this.info,
    required this.type,
    required this.onTrust,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isMismatch = type == HostKeyDialogType.keyMismatch;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMismatch ? Icons.error_outline : Icons.security,
                  color: isMismatch ? Colors.red : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMismatch ? 'Host Key Changed' : 'Unknown Host',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isMismatch
                  ? 'The host key for ${info.host}:${info.port} has changed. This could indicate a security issue or the server key was legitimately updated.'
                  : 'The authenticity of host \'${info.host}:${info.port}\' cannot be established.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Host: ${info.host}:${info.port}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Key Type: ${info.keyType}',
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fingerprint:',
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    info.displayFingerprint,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.cyan,
                    ),
                  ),
                ],
              ),
            ),
            if (isMismatch) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previously stored fingerprint:',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      info.storedDisplayFingerprint,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: Colors.red[300],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMismatch
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMismatch
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: isMismatch ? Colors.red[300] : Colors.orange[300],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMismatch
                          ? 'Continuing could expose you to a man-in-the-middle attack. Verify with your server administrator before proceeding.'
                          : 'Verify this fingerprint with your server administrator before trusting this host.',
                      style: TextStyle(
                        color: isMismatch ? Colors.red[300] : Colors.orange[300],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReject,
                  child: Text(
                    isMismatch ? 'Reject & Disconnect' : 'Cancel',
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: onTrust,
                  style: FilledButton.styleFrom(
                    backgroundColor: isMismatch ? Colors.red : Colors.green,
                  ),
                  child: Text(
                    isMismatch ? 'Trust New Key' : 'Trust & Connect',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
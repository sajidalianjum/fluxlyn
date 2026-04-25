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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
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
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isMismatch
                  ? 'The host key for ${info.host}:${info.port} has changed. This could indicate a security issue or the server key was legitimately updated.'
                  : 'The authenticity of host \'${info.host}:${info.port}\' cannot be established.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Host: ${info.host}:${info.port}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Key Type: ${info.keyType}',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fingerprint:',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    info.displayFingerprint,
                    style: TextStyle(
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
                      style: TextStyle(color: Colors.red[400]),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      info.storedDisplayFingerprint,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: Colors.red[400],
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
                    ? Colors.red.withValues(alpha: isDark ? 0.1 : 0.08)
                    : Colors.orange.withValues(alpha: isDark ? 0.1 : 0.08),
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
                    color: isMismatch ? Colors.red[400] : Colors.orange[400],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMismatch
                          ? 'Continuing could expose you to a man-in-the-middle attack. Verify with your server administrator before proceeding.'
                          : 'Verify this fingerprint with your server administrator before trusting this host.',
                      style: TextStyle(
                        color: isMismatch ? Colors.red[400] : Colors.orange[400],
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
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/storage_service.dart';
import '../../../features/settings/presentation/dialogs/master_password_setup_dialog.dart';
import '../../../features/settings/presentation/dialogs/master_password_prompt_dialog.dart';

class SplashPage extends StatefulWidget {
  final StorageService storageService;
  final void Function() onReady;

  const SplashPage({
    super.key,
    required this.storageService,
    required this.onReady,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRequirement();
  }

  Future<void> _checkRequirement() async {
    try {
      final requirement = await widget.storageService.checkPasswordRequirement();
      setState(() {
        _isLoading = false;
      });

      if (requirement == PasswordRequirement.required) {
        await _showPasswordPrompt();
      } else if (requirement == PasswordRequirement.firstLaunch) {
        await _showSetupDialog();
      } else {
        await _initializeStorage(null);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showPasswordPrompt() async {
    while (true) {
      if (!mounted) return;
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MasterPasswordPromptDialog(
          showForgotOption: true,
        ),
      );

      if (result == null) return;

      if (result == 'forgot') {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const ForgotPasswordDialog(),
        );

        if (confirmed == true) {
          try {
            setState(() {
              _isLoading = true;
              _error = null;
            });
            await widget.storageService.clearAllData();
            await _initializeStorage(null);
            return;
          } catch (e) {
            setState(() => _error = 'Failed to clear data: $e');
          }
        }
        continue;
      }

      try {
        setState(() {
          _isLoading = true;
          _error = null;
        });
        await _initializeStorage(result);
        return;
      } catch (e) {
        setState(() => _error = 'Invalid password');
      }
    }
  }

  Future<void> _showSetupDialog() async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MasterPasswordSetupDialog(),
    );

    if (password != null && password.isNotEmpty) {
      try {
        setState(() {
          _isLoading = true;
          _error = null;
        });
        await _initializeStorage(null);
        await widget.storageService.enableMasterPassword(password);
      } catch (e) {
        setState(() => _error = 'Failed to enable password: $e');
        return;
      }
    } else {
      try {
        setState(() {
          _isLoading = true;
          _error = null;
        });
        await widget.storageService.markPasswordPromptShown();
        await _initializeStorage(null);
      } catch (e) {
        setState(() => _error = 'Failed to initialize: $e');
        return;
      }
    }

    widget.onReady();
  }

  Future<void> _initializeStorage(String? password) async {
    try {
      await widget.storageService.init(masterPassword: password);
      widget.onReady();
    } catch (e) {
      throw Exception('Invalid password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.storage,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Fluxlyn',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ] else if (_error != null) ...[
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                'Error',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _checkRequirement();
                },
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
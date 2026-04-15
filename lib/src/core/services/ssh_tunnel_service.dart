import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../features/connections/models/connection_model.dart';
import '../../utils/ssh_helper.dart';
import '../constants/app_constants.dart';
import '../models/exceptions.dart';
import '../utils/error_reporter.dart';

class SSHTunnelService {
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _forwardTimeout = Duration(seconds: 5);

  SSHClient? _sshClient;
  ServerSocket? _serverSocket;
  int _localPort = 0;

  String get localHost => '127.0.0.1';
  int get localPort => _localPort;
  bool get isConnected => _sshClient != null;

  Future<void> connect(
    ConnectionModel config,
    String remoteHost,
    int remotePort,
  ) async {
    if (_sshClient != null || _serverSocket != null) {
      await disconnect();
    }

    ErrorReporter.info(
      'SSH Tunnel: Connecting to ${config.sshHost}:${config.sshPort ?? AppConstants.portSSH}',
      'SSHTunnelService.connect',
      'ssh_tunnel_service.dart:31',
    );

    SSHClient? tempClient;
    ServerSocket? tempSocket;

    try {
      final socket =
          await SSHSocket.connect(
            config.sshHost!,
            config.sshPort ?? AppConstants.portSSH,
            timeout: _connectionTimeout,
          ).timeout(
            _connectionTimeout,
            onTimeout: () {
              throw TimeoutException(
                'SSH connection timeout after ${_connectionTimeout.inSeconds} seconds',
                timeout: _connectionTimeout,
                operation: 'connect',
              );
            },
          );
      ErrorReporter.info(
        'SSH Tunnel: Socket connected',
        'SSHTunnelService.connect',
        'ssh_tunnel_service.dart:54',
      );

      final List<SSHKeyPair> keys = [];
      if (config.sshPrivateKey != null) {
        final keyText = config.sshPrivateKey!;
        if (keyText.startsWith('-----')) {
          try {
            final decryptedKeys = await compute(decryptSSHKeyPairs, [
              keyText,
              config.sshKeyPassword ?? '',
            ]);
            keys.addAll(decryptedKeys);
          } catch (e) {
            throw SSHException(
              'Failed to decrypt SSH private key',
              host: config.sshHost,
              port: config.sshPort,
              originalError: e,
            );
          }
        } else {
          try {
            final file = File(keyText);
            if (!file.existsSync()) {
              throw SSHException(
                'SSH private key file not found: $keyText',
                host: config.sshHost,
                port: config.sshPort,
              );
            }
            final keyContent = await file.readAsString();
            final decryptedKeys = await compute(decryptSSHKeyPairs, [
              keyContent,
              config.sshKeyPassword ?? '',
            ]);
            keys.addAll(decryptedKeys);
          } catch (e) {
            throw SSHException(
              'Failed to read SSH private key file',
              host: config.sshHost,
              port: config.sshPort,
              originalError: e,
            );
          }
        }
      }

      tempClient = SSHClient(
        socket,
        username: config.sshUsername ?? '',
        onPasswordRequest: () => config.sshPassword,
        identities: keys,
        onVerifyHostKey: (host, key) => true,
        keepAliveInterval: const Duration(seconds: 30),
      );
      ErrorReporter.info(
        'SSH Tunnel: Client created, waiting for authentication',
        'SSHTunnelService.connect',
        'ssh_tunnel_service.dart:109',
      );

      await tempClient.authenticated.timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException(
            'SSH authentication timeout after ${_connectionTimeout.inSeconds} seconds',
            timeout: _connectionTimeout,
            operation: 'authenticate',
          );
        },
      );
      ErrorReporter.info(
        'SSH Tunnel: Authenticated successfully',
        'SSHTunnelService.connect',
        'ssh_tunnel_service.dart:121',
      );

      tempSocket = await ServerSocket.bind('127.0.0.1', 0);
      _localPort = tempSocket.port;
      ErrorReporter.info(
        'SSH Tunnel: ServerSocket bound to 127.0.0.1:$localPort',
        'SSHTunnelService.connect',
        'ssh_tunnel_service.dart:125',
      );

      _sshClient = tempClient;
      _serverSocket = tempSocket;

      tempSocket.listen((socket) async {
        final resolvedRemoteHost = remoteHost == 'localhost'
            ? '127.0.0.1'
            : remoteHost;

        try {
          ErrorReporter.info(
            'SSH Tunnel: New connection received, creating forward channel to $resolvedRemoteHost:$remotePort',
            'SSHTunnelService.connect',
            'ssh_tunnel_service.dart:136',
          );

          dynamic session;
          dynamic forward;

          try {
            ErrorReporter.info(
              'SSH Tunnel: Attempting connection via netcat',
              'SSHTunnelService.connect',
              'ssh_tunnel_service.dart:144',
            );
            session = await _sshClient!
                .execute('nc $resolvedRemoteHost $remotePort')
                .timeout(
                  _forwardTimeout,
                  onTimeout: () {
                    throw TimeoutException(
                      'Netcat connection timeout',
                      timeout: _forwardTimeout,
                      operation: 'netcat',
                    );
                  },
                );

            bool ncFailed = false;
            session.stderr.listen((data) {
              final err = String.fromCharCodes(data).toLowerCase();
              if (err.contains('not found') || err.contains('not recognized')) {
                ncFailed = true;
              }
            });

            await Future.delayed(const Duration(milliseconds: 200));

            if (ncFailed) {
              throw Exception('nc not found');
            }

            ErrorReporter.info(
              'SSH Tunnel: Netcat session started',
              'SSHTunnelService.connect',
              'ssh_tunnel_service.dart:172',
            );
            socket.setOption(SocketOption.tcpNoDelay, true);

            session.stdout.listen(
              (data) => socket.add(data),
              onDone: () => socket.close(),
              onError: (e) => socket.close(),
            );

            socket.listen(
              (data) => session.stdin.add(data),
              onDone: () => session.stdin.close(),
              onError: (e) => session.stdin.close(),
            );

            await session.done;
            ErrorReporter.info(
              'SSH Tunnel: Netcat session closed',
              'SSHTunnelService.connect',
              'ssh_tunnel_service.dart:188',
            );
          } catch (e) {
            ErrorReporter.info(
              'SSH Tunnel: Netcat failed or not found ($e), falling back to direct-tcpip',
              'SSHTunnelService.connect',
              'ssh_tunnel_service.dart:190',
            );

            try {
              forward = await _sshClient!
                  .forwardLocal(resolvedRemoteHost, remotePort)
                  .timeout(
                    _forwardTimeout,
                    onTimeout: () {
                      throw TimeoutException(
                        'SSH forward timeout',
                        timeout: _forwardTimeout,
                        operation: 'forwardLocal',
                      );
                    },
                  );
              ErrorReporter.info(
                'SSH Tunnel: Direct forward channel created',
                'SSHTunnelService.connect',
                'ssh_tunnel_service.dart:207',
              );

              socket.setOption(SocketOption.tcpNoDelay, true);

              forward.stream.listen(
                (data) => socket.add(data),
                onDone: () => socket.close(),
                onError: (e) => socket.close(),
              );

              socket.listen(
                (data) => forward.sink.add(data),
                onDone: () => forward.sink.close(),
                onError: (e) => forward.sink.close(),
              );

              await forward.done;
              ErrorReporter.info(
                'SSH Tunnel: Direct forward channel closed',
                'SSHTunnelService.connect',
                'ssh_tunnel_service.dart:224',
              );
            } catch (forwardError, stackTrace) {
              ErrorReporter.warning(
                'SSH Tunnel: Forward error - $forwardError',
                stackTrace,
                'SSHTunnelService.connect',
                'ssh_tunnel_service.dart:226',
              );
              socket.close();
            }
          }
        } catch (e, stackTrace) {
          ErrorReporter.warning(
            'SSH Tunnel: Forward error - $e',
            stackTrace,
            'SSHTunnelService.connect',
            'ssh_tunnel_service.dart:231',
          );
          socket.close();
        }
      });
      ErrorReporter.info(
        'SSH Tunnel: Listener started',
        'SSHTunnelService.connect',
        'ssh_tunnel_service.dart:235',
      );
      ErrorReporter.info(
        'SSH Tunnel: Ready to connect via $localHost:$localPort',
        'SSHTunnelService.connect',
        'ssh_tunnel_service.dart:236',
      );
    } on TimeoutException {
      await _cleanupTempResources(tempClient, tempSocket);
      rethrow;
    } on SSHException {
      await _cleanupTempResources(tempClient, tempSocket);
      rethrow;
    } catch (e) {
      await _cleanupTempResources(tempClient, tempSocket);
      throw SSHException(
        'SSH Connection Failed: ${e.toString()}',
        host: config.sshHost,
        port: config.sshPort,
        originalError: e,
      );
    }
  }

  Future<void> _cleanupTempResources(
    SSHClient? client,
    ServerSocket? socket,
  ) async {
    try {
      if (socket != null) {
        try {
          await socket.close();
        } catch (_) {}
      }
    } catch (_) {}
    try {
      if (client != null) {
        client.close();
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      await _serverSocket?.close();
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Error closing SSH server socket: $e',
        stackTrace,
        'SSHTunnelService.disconnect',
        'ssh_tunnel_service.dart:276',
      );
    }
    _serverSocket = null;
    if (_sshClient != null) {
      try {
        _sshClient!.close();
      } catch (e, stackTrace) {
        ErrorReporter.warning(
          'Error closing SSH client: $e',
          stackTrace,
          'SSHTunnelService.disconnect',
          'ssh_tunnel_service.dart:283',
        );
      }
      _sshClient = null;
    }
    _localPort = 0;
  }
}

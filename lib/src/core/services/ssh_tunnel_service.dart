import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../features/connections/models/connection_model.dart';
import '../../utils/ssh_helper.dart';
import '../constants/app_constants.dart';

class SSHTunnelService {
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
    print(
      'SSH Tunnel: Connecting to ${config.sshHost}:${config.sshPort ?? AppConstants.portSSH}',
    );

    try {
      final socket = await SSHSocket.connect(
        config.sshHost!,
        config.sshPort ?? AppConstants.portSSH,
        timeout: const Duration(seconds: 10),
      );
      print('SSH Tunnel: Socket connected');

      final List<SSHKeyPair> keys = [];
      if (config.sshPrivateKey != null) {
        final keyText = config.sshPrivateKey!;
        if (keyText.startsWith('-----')) {
          final decryptedKeys = await compute(decryptSSHKeyPairs, [
            keyText,
            config.sshKeyPassword ?? '',
          ]);
          keys.addAll(decryptedKeys);
        } else {
          final file = File(keyText);
          if (file.existsSync()) {
            final keyContent = await file.readAsString();
            final decryptedKeys = await compute(decryptSSHKeyPairs, [
              keyContent,
              config.sshKeyPassword ?? '',
            ]);
            keys.addAll(decryptedKeys);
          }
        }
      }

      _sshClient = SSHClient(
        socket,
        username: config.sshUsername ?? '',
        onPasswordRequest: () => config.sshPassword,
        identities: keys,
        onVerifyHostKey: (host, key) => true,
        keepAliveInterval: const Duration(seconds: 30),
      );
      print('SSH Tunnel: Client created, waiting for authentication...');

      await _sshClient!.authenticated;
      print('SSH Tunnel: Authenticated successfully');

      _serverSocket = await ServerSocket.bind('127.0.0.1', 0);
      _localPort = _serverSocket!.port;
      print('SSH Tunnel: ServerSocket bound to 127.0.0.1:$_localPort');

      _serverSocket!.listen((socket) async {
        try {
          print(
            'SSH Tunnel: New connection received, creating forward channel to $remoteHost:$remotePort',
          );

          final resolvedRemoteHost = remoteHost == 'localhost'
              ? '127.0.0.1'
              : remoteHost;

          try {
            print('SSH Tunnel: Attempting connection via netcat...');
            final session = await _sshClient!.execute(
              'nc $resolvedRemoteHost $remotePort',
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

            print('SSH Tunnel: Netcat session started');
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
            print('SSH Tunnel: Netcat session closed');
          } catch (e) {
            print(
              'SSH Tunnel: Netcat failed or not found ($e), falling back to direct-tcpip...',
            );

            final forward = await _sshClient!.forwardLocal(
              resolvedRemoteHost,
              remotePort,
            );
            print('SSH Tunnel: Direct forward channel created');

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
            print('SSH Tunnel: Direct forward channel closed');
          }
        } catch (e) {
          print('SSH Tunnel: Forward error - $e');
          socket.close();
        }
      });
      print('SSH Tunnel: Listener started');
      print('SSH Tunnel: Ready to connect via $localHost:$localPort');
    } catch (e) {
      print('SSH Tunnel: Error - $e');
      await disconnect();
      throw Exception('SSH Connection Failed: $e');
    }
  }

  Future<void> disconnect() async {
    await _serverSocket?.close();
    _serverSocket = null;
    if (_sshClient != null) {
      _sshClient!.close();
      _sshClient = null;
    }
    _localPort = 0;
  }
}

import 'dart:developer' as developer;
import 'dart:async';

import 'package:signalr_core/signalr_core.dart';

import '../constants.dart';

/// Simple wrapper around `signalr_core` with robust connect/reconnect probing.
class SignalRClient {
  static final SignalRClient _instance = SignalRClient._internal();
  factory SignalRClient() => _instance;
  SignalRClient._internal();

  HubConnection? _conn;

  bool get isConnected => _conn?.state == HubConnectionState.connected;

  /// Try to connect to a SignalR hub. Will attempt a few common hub path
  /// variants if the first one returns a 404 negotiate.
  Future<void> connect({String hubPath = '/gameHub', String? accessToken}) async {
    // Stop previous connection if present
    try {
      await stop();
    } catch (_) {}

    final candidates = <String>[];
    // ensure hubPath starts with '/'
    final baseHub = hubPath.startsWith('/') ? hubPath : '/$hubPath';
    candidates.add(baseHub);
    // common variants
    if (!baseHub.toLowerCase().contains('hub')) {
      candidates.add('/${baseHub.replaceFirst('/', '')}Hub');
    }
    candidates.add('/hubs${baseHub}');
    candidates.add('/hubs/${baseHub.replaceFirst('/', '')}');
    candidates.add('/signalr${baseHub}');

    final options = HttpConnectionOptions(
      accessTokenFactory: accessToken != null ? () async => accessToken : null,
    );

    Exception? lastError;
    for (final candidate in candidates) {
      final url = wsBaseUrl.replaceFirst('wss://', 'https://') + candidate;
      developer.log('[SignalR] trying hub url: $url', name: 'SignalRClient');
      try {
        final conn = HubConnectionBuilder().withUrl(url, options).withAutomaticReconnect().build();
        // Start with a timeout so a bad negotiate doesn't hang the app
        final startF = conn.start();
        if (startF != null) {
          await startF.timeout(const Duration(seconds: 6));
        } else {
          throw Exception('SignalR start returned null');
        }

        // succeeded
        _conn = conn;

        // Lifecycle logging and hooks for reconnection
        try {
          _conn!.onreconnecting((error) {
            developer.log('[SignalR] reconnecting: ${error?.toString() ?? 'unknown'}', name: 'SignalRClient');
          });

          _conn!.onreconnected((connectionId) {
            developer.log('[SignalR] reconnected, connectionId: $connectionId', name: 'SignalRClient');
          });

          _conn!.onclose((error) {
            developer.log('[SignalR] connection closed: ${error?.toString() ?? 'none'}', name: 'SignalRClient');
          });
        } catch (_) {}

        developer.log('[SignalR] connected to $url', name: 'SignalRClient');
        return;
      } catch (e) {
        // If negotiate returned 404, it's likely the path is wrong — try next candidate
        developer.log('[SignalR] connect candidate failed: ${e.toString()}', name: 'SignalRClient');
        lastError = e is Exception ? e : Exception(e.toString());
        // If the error contains "404" or "negotiate" we prefer to try other candidates
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('404') || errStr.contains('negotiate')) {
          continue;
        }
        // For other errors, continue attempting other candidates as well
      }
    }

    // If we reach here, none of the candidates succeeded
    throw Exception('SignalR connect failed: ${lastError?.toString() ?? 'no candidates succeeded'}');
  }

  Future<void> stop() async {
    try {
      final fut = _conn?.stop();
      if (fut != null) {
        try {
          await fut.timeout(const Duration(seconds: 4));
        } catch (_) {
          // ignore stop timeout
        }
      }
    } catch (_) {}
    _conn = null;
  }

  void on(String methodName, void Function(List<Object?>? args) callback) {
    _conn?.on(methodName, callback);
  }

  Future<void> invoke(String methodName, {List<Object?>? args}) async {
    if (_conn == null) throw Exception('Connection not started');
    // If the connection exists but isn't connected, try to start it.
    if (_conn!.state != HubConnectionState.connected) {
        try {
          final sf = _conn!.start();
          if (sf != null) {
            await sf.timeout(const Duration(seconds: 6));
          } else {
            throw Exception('SignalR start returned null');
          }
        } catch (e) {
        throw Exception('Connection not in Connected state and reconnect failed: ${e.toString()}');
      }
    }
    await _conn!.invoke(methodName, args: args);
  }
}


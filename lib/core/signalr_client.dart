import 'dart:developer' as developer;
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:signalr_core/signalr_core.dart';

import '../constants.dart';

/// Simple wrapper around `signalr_core` with robust connect/reconnect probing.
class SignalRClient {
  static final SignalRClient _instance = SignalRClient._internal();
  factory SignalRClient() => _instance;
  SignalRClient._internal();

  HubConnection? _conn;

  bool get isConnected => _conn?.state == HubConnectionState.connected;

  /// Connect to the configured SignalR hub. Uses a single, fixed hub path
  /// of `/hubs/game` (as required by the backend) and sends an access token
  /// via the `accessTokenFactory` query parameter when provided.
  Future<void> connect({String? accessToken}) async {
    // Stop previous connection if present
    try {
      await stop();
    } catch (_) {}

    // Build the single, fixed hub URL required by the server
    final url = wsBaseUrl.replaceFirst('wss://', 'https://') + signalRHubPath;
    developer.log('[SignalR] connecting to hub url: $url', name: 'SignalRClient');

    final options = HttpConnectionOptions(
      accessTokenFactory: accessToken != null ? () async => accessToken : null,
    );

    try {
      final conn = HubConnectionBuilder().withUrl(url, options).withAutomaticReconnect().build();
      final startF = conn.start();
      if (startF == null) throw Exception('SignalR start returned null');
      await startF.timeout(const Duration(seconds: 8));

      _conn = conn;

      // Lifecycle logging
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
      developer.log('[SignalR] connect failed: ${e.toString()}', name: 'SignalRClient');
      // Attempt a lightweight diagnostic call to the negotiate endpoint
      try {
        final diagUrl = apiBaseUrl + signalRHubPath + '/negotiate';
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (accessToken != null && accessToken.isNotEmpty) headers['Authorization'] = 'Bearer $accessToken';
        developer.log('[SignalR] diagnostic negotiate call to $diagUrl', name: 'SignalRClient');
        final resp = await http.post(Uri.parse(diagUrl), headers: headers).timeout(const Duration(seconds: 6));
        developer.log('[SignalR] negotiate diag status=${resp.statusCode} body=${resp.body}', name: 'SignalRClient');
      } catch (diagErr) {
        developer.log('[SignalR] negotiate diagnostic failed: ${diagErr.toString()}', name: 'SignalRClient');
      }

      throw Exception('SignalR connect failed: ${e.toString()}');
    }
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


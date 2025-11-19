import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants.dart';

/// Simple WebSocket client wrapper. Connects to `wsBaseUrl` and exposes
/// a stream of decoded JSON messages. Keep it minimal and reusable.
class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._internal();
  factory WebSocketClient() => _instance;
  WebSocketClient._internal();

  WebSocketChannel? _channel;

  Stream<dynamic>? get stream => _channel?.stream;

  Future<void> connect([String path = '']) async {
    final uri = Uri.parse(wsBaseUrl + path);
    _channel = WebSocketChannel.connect(uri);
  }

  void send(Map<String, dynamic> message) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }
}

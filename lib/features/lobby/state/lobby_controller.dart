import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/api_client.dart';
import '../../../core/models/room_summary_dto.dart';

class LobbyController extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<RoomSummaryDto> rooms = [];
  bool loading = false;
  String? error;

  Timer? _pollTimer;

  /// Para indicar cuando el backend dice "ya estabas en esta sala"
  bool lastJoinAlreadyInRoom = false;

  // ==============================================================
  // LOAD ROOMS
  // ==============================================================
  Future<void> loadRooms() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _api.getJson('/api/Lobby/rooms');
      final list = (data as List)
          .map((e) => RoomSummaryDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      rooms = list;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==============================================================
  // GET ROOM BY ID
  // ==============================================================
  Future<RoomSummaryDto?> getRoomById(String id) async {
    try {
      final data = await _api.getJson('/api/Lobby/rooms/$id');
      return RoomSummaryDto.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      error = e.toString();
      return null;
    }
  }

  // ==============================================================
  // CREATE ROOM
  // ==============================================================
  Future<RoomSummaryDto?> createRoom(String name, {int maxPlayers = 4}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final body = {
        'name': name,
        'maxPlayers': maxPlayers,
      };

      final data = await _api.postJson('/api/Lobby/rooms', body);
      final room = RoomSummaryDto.fromJson(Map<String, dynamic>.from(data));

      rooms.add(room);
      notifyListeners();
      return room;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==============================================================
  // JOIN ROOM
  // ==============================================================
  Future<bool> joinRoom(String roomId) async {
    error = null;
    lastJoinAlreadyInRoom = false;
    notifyListeners();

    try {
      final body = {'roomId': roomId};

      final data = await _api.postJson('/api/Lobby/rooms/join', body);
      final result = Map<String, dynamic>.from(data);

      if (result['alreadyInRoom'] == true) {
        lastJoinAlreadyInRoom = true;
      }

      return true;
    } catch (e) {
      final msg = e.toString();

      if (msg.contains('already') || msg.contains('Already')) {
        lastJoinAlreadyInRoom = true;
        return true;
      }

      error = msg;
      return false;
    } finally {
      notifyListeners();
    }
  }

  // ==============================================================
  // NEW: CREATE GAME (public)
  // ==============================================================
  Future<Map<String, dynamic>> createGame(String roomId) async {
    final body = {'roomId': roomId};
    final data = await _api.postJson('/api/Games', body);
    return Map<String, dynamic>.from(data);
  }

  // ==============================================================
  // POLLING
  // ==============================================================
  void startPolling({int intervalSeconds = 60}) {
    stopPolling();

    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => loadRooms(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

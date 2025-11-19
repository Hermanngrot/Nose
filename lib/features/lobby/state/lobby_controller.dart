import 'package:flutter/material.dart';

import '../../../core/models/room_summary_dto.dart';
import '../../../core/services/lobby_service.dart';
import 'dart:async';

class LobbyController extends ChangeNotifier {
  final LobbyService _service = LobbyService();

  bool loading = false;
  List<RoomSummaryDto> rooms = [];
  String? error;
  Timer? _pollTimer;
  /// If the last join attempt found the user was already in the room,
  /// this is set to true.
  bool lastJoinAlreadyInRoom = false;

  Future<void> loadRooms() async {
    loading = true; error = null; notifyListeners();
    try {
      final fetched = await _service.getRooms();
      // Merge fetched list with cached `rooms` to avoid losing detailed data
      final Map<String, RoomSummaryDto> existingById = { for (var r in rooms) r.id : r };
      final List<RoomSummaryDto> merged = [];

      // Merge fetched entries, preferring existing detailed playerNames when available
      for (final fr in fetched) {
        final existing = existingById[fr.id];
        if (existing != null) {
          final players = (fr.playerNames.isEmpty && existing.playerNames.isNotEmpty) ? existing.playerNames : fr.playerNames;
          final mergedRoom = RoomSummaryDto(
            id: fr.id,
            name: fr.name,
            players: fr.players,
            maxPlayers: fr.maxPlayers,
              playerNames: players,
              ownerId: fr.ownerId,
              ownerName: fr.ownerName,
              status: fr.status,
              gameId: fr.gameId,
          );
          merged.add(mergedRoom);
        } else {
          merged.add(fr);
        }
      }

      // Preserve any existing rooms that weren't present in the fetched summary
      for (final ex in rooms) {
        if (!merged.any((m) => m.id == ex.id)) {
          merged.add(ex);
        }
      }

      rooms = merged;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// Creates a room and returns the created [RoomSummaryDto], or null on failure.
  Future<RoomSummaryDto?> createRoom(String name) async {
    loading = true; error = null; notifyListeners();
    try {
      final room = await _service.createRoom(name);
      // reload rooms from server to ensure consistent view for everyone
      await loadRooms();
      return room;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<bool> joinRoom(String roomId) async {
    loading = true; error = null; notifyListeners();
    lastJoinAlreadyInRoom = false;
    try {
      await _service.joinRoom(roomId);
      return true;
    } catch (e) {
      // If joining failed, attempt to fetch the room. It's possible the
      // user is already in the room (server may return an error). In that
      // case, allow proceeding by returning true if the room exists.
      error = e.toString();
      try {
        final existing = await getRoomById(roomId);
        if (existing != null) {
          lastJoinAlreadyInRoom = true;
          return true;
        }
      } catch (_) {}
      return false;
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<RoomSummaryDto?> getRoomById(String roomId) async {
    loading = true; error = null; notifyListeners();
    try {
      final r = await _service.getRoom(roomId);
      // Update cached rooms so UI (waiting room) sees latest players
      final idx = rooms.indexWhere((x) => x.id == r.id);
      if (idx >= 0) {
        rooms[idx] = r;
      } else {
        rooms.add(r);
      }
      notifyListeners();
      return r;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// Start periodic polling of rooms. Interval in seconds.
  ///
  /// Default changed to 120s so the lobby updates less frequently by default.
  void startPolling({int intervalSeconds = 120}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      await loadRooms();
    });
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

import '../api_client.dart';
import '../models/room_summary_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class LobbyService {
  final ApiClient _client = ApiClient();

  Future<List<RoomSummaryDto>> getRooms() async {
    developer.log('LobbyService.getRooms: calling /api/Lobby/rooms', name: 'LobbyService');
    final resp = await _client.getJson('/api/Lobby/rooms');
    developer.log('LobbyService.getRooms: response: $resp', name: 'LobbyService');
    // expect resp to be an object with 'rooms' or an array directly
    dynamic data;
    if (resp is Map) {
      data = resp['rooms'] ?? resp['data'] ?? resp;
    } else {
      data = resp;
    }
    if (data is List) {
      return data.map((e) => RoomSummaryDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    return [];
  }

  Future<RoomSummaryDto> createRoom(String name, {int maxPlayers = 4}) async {
    final body = {'name': name, 'maxPlayers': maxPlayers};
    developer.log('LobbyService.createRoom: POST /api/Lobby/rooms body=$body', name: 'LobbyService');
    final resp = await _client.postJson('/api/Lobby/rooms', body);
    developer.log('LobbyService.createRoom: response: $resp', name: 'LobbyService');
    if (resp is Map) return RoomSummaryDto.fromJson(Map<String, dynamic>.from(resp));
    throw Exception('Unexpected createRoom response: ${resp.runtimeType}');
  }

  Future<void> joinRoom(String roomId) async {
    // Send roomId as integer when possible (spec expects integer)
    final int? parsedId = int.tryParse(roomId);
    final body = <String, dynamic>{'roomId': parsedId ?? roomId};

    // Try multiple join variants to be compatible with different backend routes
    try {
      developer.log('LobbyService.joinRoom: POST /api/Lobby/rooms/join body=$body', name: 'LobbyService');
      final r1 = await _client.postJson('/api/Lobby/rooms/join', body);
      developer.log('LobbyService.joinRoom: response1: $r1', name: 'LobbyService');
      return;
    } catch (e) {
      developer.log('LobbyService.joinRoom: first attempt failed: ${e.toString()}', name: 'LobbyService');
      // try alternative route: /api/Lobby/rooms/{id}/join
      try {
        final path = parsedId != null ? '/api/Lobby/rooms/$parsedId/join' : '/api/Lobby/rooms/$roomId/join';
        developer.log('LobbyService.joinRoom: POST $path', name: 'LobbyService');
        final r2 = await _client.postJson(path, <String, dynamic>{});
        developer.log('LobbyService.joinRoom: response2: $r2', name: 'LobbyService');
        return;
      } catch (e2) {
        developer.log('LobbyService.joinRoom: second attempt failed: ${e2.toString()}', name: 'LobbyService');
        // try another common variant: POST to /api/Lobby/rooms/{id}/players (some APIs use this)
        try {
          final prefs = await SharedPreferences.getInstance();
          final username = prefs.getString('username') ?? '';
          final tryBody = username.isNotEmpty ? {'username': username} : <String, dynamic>{};
          final path = parsedId != null ? '/api/Lobby/rooms/$parsedId/players' : '/api/Lobby/rooms/$roomId/players';
          developer.log('LobbyService.joinRoom: POST $path body=$tryBody', name: 'LobbyService');
          final r3 = await _client.postJson(path, tryBody);
          developer.log('LobbyService.joinRoom: response3: $r3', name: 'LobbyService');
          return;
        } catch (e3) {
          developer.log('LobbyService.joinRoom: third attempt failed: ${e3.toString()}', name: 'LobbyService');
          // All attempts failed — rethrow composite error for controller to handle
          throw Exception('Join failed: ${e.toString()} | ${e2.toString()} | ${e3.toString()}');
        }
      }
    }
  }

  Future<RoomSummaryDto> getRoom(String roomId) async {
    developer.log('LobbyService.getRoom: GET /api/Lobby/rooms/$roomId', name: 'LobbyService');
    final resp = await _client.getJson('/api/Lobby/rooms/$roomId');
    developer.log('LobbyService.getRoom: response: $resp', name: 'LobbyService');
    if (resp is Map) return RoomSummaryDto.fromJson(Map<String, dynamic>.from(resp));
    throw Exception('Unexpected getRoom response: ${resp.runtimeType}');
  }
}

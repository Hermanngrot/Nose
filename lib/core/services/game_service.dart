import '../api_client.dart';
import '../models/game_state_dto_clean.dart';
import 'dart:developer' as developer;

class GameService {
  final ApiClient _client = ApiClient();

  Future<GameStateDto> createGame({String? roomId}) async {
    // Ensure roomId is sent as integer when possible (OpenAPI expects integer)
    final int? parsedId = roomId != null ? int.tryParse(roomId) : null;
    final Map<String, dynamic> body = parsedId != null ? {'roomId': parsedId} : (roomId != null ? {'roomId': roomId} : <String, dynamic>{});
    final resp = await _client.postJson('/api/Games', body);
    if (resp is Map) return GameStateDto.fromJson(Map<String, dynamic>.from(resp));
    throw Exception('Unexpected createGame response: ${resp.runtimeType}');
  }

  Future<GameStateDto> getGame(String gameId) async {
    final resp = await _client.getJson('/api/Games/$gameId');
    if (resp is Map) return GameStateDto.fromJson(Map<String, dynamic>.from(resp));
    throw Exception('Unexpected getGame response: ${resp.runtimeType}');
  }

  /// Try to find an active game associated with a room id.
  /// Probes several common endpoints and returns null if none found.
  Future<GameStateDto?> getGameByRoom(String roomId) async {
    try {
      final candidates = [
        '/api/Games/byRoom/$roomId',
        '/api/Games/room/$roomId',
        '/api/Games/rooms/$roomId',
        '/api/Games?roomId=$roomId',
        // Lobby endpoints that may contain a pointer to the current game
        '/api/Lobby/rooms/$roomId',
        '/api/Lobby/rooms/$roomId/game',
        '/api/Lobby/rooms/$roomId/currentGame',
      ];

      for (final path in candidates) {
        try {
          developer.log('GameService.getGameByRoom: trying $path', name: 'GameService');
          final resp = await _client.getJson(path);

          // If response is a list, inspect first element
          if (resp is List && resp.isNotEmpty) {
            final first = resp.first;
            if (first is Map) {
              final firstMap = Map<String, dynamic>.from(first);
              developer.log('GameService.getGameByRoom: list response at $path keys=${firstMap.keys.toList()}', name: 'GameService');
              if ((firstMap['id'] ?? firstMap['gameId']) != null || firstMap.containsKey('players')) {
                return GameStateDto.fromJson(firstMap);
              }
              final possible = (firstMap['gameId'] ?? firstMap['currentGameId'] ?? firstMap['currentGame'] ?? firstMap['activeGame']);
              if (possible != null) {
                return await getGame(possible.toString());
              }
            }
          }

          if (resp is Map) {
            final mapResp = Map<String, dynamic>.from(resp);
            developer.log('GameService.getGameByRoom: map response at $path keys=${mapResp.keys.toList()}', name: 'GameService');

            if ((mapResp['id'] ?? mapResp['gameId']) != null || mapResp.containsKey('players')) {
              return GameStateDto.fromJson(mapResp);
            }

            if (mapResp['game'] is Map) {
              return GameStateDto.fromJson(Map<String, dynamic>.from(mapResp['game'] as Map));
            }

            if (mapResp['data'] is Map) {
              final data = Map<String, dynamic>.from(mapResp['data'] as Map);
              if ((data['id'] ?? data['gameId']) != null || data.containsKey('players')) {
                return GameStateDto.fromJson(data);
              }
            }

            final pointer = (mapResp['gameId'] ?? mapResp['currentGameId'] ?? mapResp['currentGame'] ?? mapResp['activeGame'] ?? mapResp['game']);
            if (pointer != null) {
              return await getGame(pointer.toString());
            }
          }
        } catch (e) {
          developer.log('GameService.getGameByRoom: candidate $path failed: ${e.toString()}', name: 'GameService');
        }
      }

      // Final attempt: scan /api/Games list and match on room reference
      try {
        developer.log('GameService.getGameByRoom: probing /api/Games list for roomId=$roomId', name: 'GameService');
        final all = await _client.getJson('/api/Games');
        if (all is List) {
          for (final item in all) {
            try {
              if (item is Map) {
                final mapItem = Map<String, dynamic>.from(item);
                final candidateRoom = (mapItem['roomId'] ?? mapItem['room'] ?? mapItem['lobbyId'] ?? mapItem['room_id']);
                if (candidateRoom != null && candidateRoom.toString() == roomId) {
                  final idVal = mapItem['id'] ?? mapItem['gameId'];
                  if (idVal != null) return await getGame(idVal.toString());
                  return GameStateDto.fromJson(mapItem);
                }
                if (mapItem['room'] is Map) {
                  final rm = Map<String, dynamic>.from(mapItem['room'] as Map);
                  if ((rm['id'] ?? rm['roomId'])?.toString() == roomId) {
                    final idVal = mapItem['id'] ?? mapItem['gameId'];
                    if (idVal != null) return await getGame(idVal.toString());
                    return GameStateDto.fromJson(mapItem);
                  }
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        developer.log('GameService.getGameByRoom: scanning /api/Games failed: ${e.toString()}', name: 'GameService');
      }
    } catch (e) {
      developer.log('GameService.getGameByRoom: unexpected error: ${e.toString()}', name: 'GameService');
    }
    developer.log('GameService.getGameByRoom: no active game found for room $roomId', name: 'GameService');
    return null;
  }
}

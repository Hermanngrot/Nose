import 'player_state_dto.dart';
import 'snake_dto.dart';
import 'ladder_dto.dart';

class GameStateDto {
  final String id;
  final List<PlayerStateDto> players;
  final String status; // e.g., waiting, in_progress, finished
  final List<SnakeDto> snakes;
  final List<LadderDto> ladders;

  GameStateDto({required this.id, required this.players, required this.status, List<SnakeDto>? snakes, List<LadderDto>? ladders})
      : snakes = snakes ?? [],
        ladders = ladders ?? [];

  factory GameStateDto.fromJson(Map<String, dynamic> json) {
    final playersRaw = json['players'] as List<dynamic>? ?? [];
    final players = playersRaw.map((e) => PlayerStateDto.fromJson(e as Map<String, dynamic>)).toList();
    // Parse board snakes and ladders (backend returns board:{ snakes:[], ladders:[] })
    final boardRaw = json['board'] as Map<String, dynamic>? ?? json['Board'] as Map<String, dynamic>?;
    List<SnakeDto> parseSnakes(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => SnakeDto.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    }
    List<LadderDto> parseLadders(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => LadderDto.fromJson(e as Map<String, dynamic>)).toList();
      return [];
    }

    final snakes = parseSnakes(boardRaw?['snakes'] ?? boardRaw?['Snakes'] ?? json['snakes']);
    final ladders = parseLadders(boardRaw?['ladders'] ?? boardRaw?['Ladders'] ?? json['ladders']);

    return GameStateDto(
      id: (json['id'] ?? json['gameId'])?.toString() ?? '',
      players: players,
      status: json['status'] as String? ?? 'unknown',
      snakes: snakes,
      ladders: ladders,
    );
  }
}

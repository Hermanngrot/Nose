import 'dart:convert';

class RoomSummaryDto {
  final String id;
  final String name;
  final int currentPlayers;
  final int maxPlayers;
  final String status;
  final List<String> playerNames;
  final String? gameId;  // 👈 NECESARIO PARA QUE AMBOS JUGADORES ENTREN AL GAME

  RoomSummaryDto({
    required this.id,
    required this.name,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.status,
    required this.playerNames,
    this.gameId,
  });

  factory RoomSummaryDto.fromJson(Map<String, dynamic> json) {
    return RoomSummaryDto(
      id: (json['id'] ?? json['roomId']).toString(),
      name: (json['name'] ?? json['roomName'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      currentPlayers: json['currentPlayers'] ?? json['players'] ?? 0,
      maxPlayers: json['maxPlayers'] ?? json['capacity'] ?? 0,
      playerNames: (json['playerNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      // 👇 AQUÍ EL PROBLEMA: lo agregamos
      gameId: json['gameId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
      'playerNames': playerNames,
      'gameId': gameId, // 👈 IMPORTANTE
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}

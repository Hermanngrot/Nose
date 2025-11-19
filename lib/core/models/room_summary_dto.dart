class RoomSummaryDto {
  final String id;
  final String name;
  final int players;
  final int maxPlayers;
  final List<String> playerNames;
  final String? ownerId;
  final String? ownerName;
  final String? status;
  final String? gameId;

  RoomSummaryDto({required this.id, required this.name, required this.players, required this.maxPlayers, this.playerNames = const [], this.ownerId, this.ownerName, this.status, this.gameId});

  factory RoomSummaryDto.fromJson(Map<String, dynamic> json) {
    // parse player names from different shapes and nested structures
    List<String> names = [];
    final possibleLists = [
      'playerNames',
      'playersList',
      'players',
      'users',
      'participants',
      'members'
    ];

    dynamic pRaw;
    for (final key in possibleLists) {
      if (json.containsKey(key) && json[key] != null) {
        pRaw = json[key];
        break;
      }
    }

    if (pRaw is List) {
      for (final e in pRaw) {
        if (e is String) {
          names.add(e);
        } else if (e is Map) {
          // If item is a nested object, try common fields
          final candidates = [
            'username',
            'userName',
            'name',
            'displayName',
            'playerName',
            'nick'
          ];
          String? found;
          for (final c in candidates) {
            if (e[c] != null) {
              found = e[c].toString();
              break;
            }
          }
          // check nested 'user' or 'player' objects
          if (found == null) {
            if (e['user'] is Map) {
              final nested = e['user'] as Map;
              for (final c in candidates) {
                if (nested[c] != null) {
                  found = nested[c].toString();
                  break;
                }
              }
            } else if (e['player'] is Map) {
              final nested = e['player'] as Map;
              for (final c in candidates) {
                if (nested[c] != null) {
                  found = nested[c].toString();
                  break;
                }
              }
            }
          }
          if (found != null) names.add(found);
        }
      }
    }

    // fallback: if players is a number but no names parsed, we keep empty names list
    int playersCount = 0;
    if (json['players'] is int) playersCount = json['players'] as int;
    else if (json['currentPlayers'] is int) playersCount = json['currentPlayers'] as int;
    else if (json['playersCount'] is int) playersCount = json['playersCount'] as int;
    else playersCount = names.length;

    final maxPlayers = (json['maxPlayers'] as int?) ?? (json['capacity'] as int?) ?? (json['max'] as int?) ?? 0;

    // optional status and gameId fields
    String? status;
    if (json['status'] != null) status = json['status'].toString();
    else if (json['state'] != null) status = json['state'].toString();

    String? gameId;
    if (json['gameId'] != null) gameId = json['gameId'].toString();
    else if (json['currentGameId'] != null) gameId = json['currentGameId'].toString();
    else if (json['activeGameId'] != null) gameId = json['activeGameId'].toString();
    else if (json['game'] is Map && (json['game'] as Map)['id'] != null) gameId = (json['game'] as Map)['id'].toString();

    return RoomSummaryDto(
      id: (json['id'] ?? json['roomId'])?.toString() ?? '',
      name: json['name'] as String? ?? (json['roomName'] as String? ?? ''),
      players: playersCount,
      maxPlayers: maxPlayers,
      playerNames: names,
      ownerId: (json['ownerId'] ?? json['hostId'])?.toString(),
      ownerName: json['ownerName'] as String? ?? json['hostName'] as String?,
      status: status,
      gameId: gameId,
    );
  }
}

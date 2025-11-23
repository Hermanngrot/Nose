class PlayerStateDto {
  final String id;
  final String username;
  final int position;
  final bool isTurn;

  PlayerStateDto({required this.id, required this.username, required this.position, required this.isTurn});

  factory PlayerStateDto.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return false;
    }

    final dynamic isTurnRaw = json['isTurn'] ?? json['turn'] ?? json['isCurrent'] ?? json['current'] ?? json['active'] ?? json['hasTurn'] ?? json['isPlaying'];

    String idVal = (json['id'] ?? json['playerId'])?.toString() ?? '';
    String usernameVal = (json['username'] ?? json['name'] ?? '').toString();

    int positionVal = 0;
    final dynamic posRaw = json['position'] ?? json['pos'] ?? json['posicion'];
    if (posRaw is int) {
      positionVal = posRaw;
    } else if (posRaw is double) {
      positionVal = posRaw.toInt();
    } else if (posRaw is String) {
      positionVal = int.tryParse(posRaw) ?? 0;
    }

    return PlayerStateDto(
      id: idVal,
      username: usernameVal,
      position: positionVal,
      isTurn: parseBool(isTurnRaw),
    );
  }
}

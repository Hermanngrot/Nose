class PlayerStateDto {
  final String id;
  final String username;
  final int position;
  final bool isTurn;

  PlayerStateDto({required this.id, required this.username, required this.position, required this.isTurn});

  factory PlayerStateDto.fromJson(Map<String, dynamic> json) {
    return PlayerStateDto(
      id: (json['id'] ?? json['playerId'])?.toString() ?? '',
      username: json['username'] as String? ?? (json['name'] as String? ?? ''),
      position: (json['position'] as int?) ?? 0,
      isTurn: (json['isTurn'] as bool?) ?? false,
    );
  }
}

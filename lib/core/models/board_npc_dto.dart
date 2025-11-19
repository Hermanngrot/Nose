class BoardNpcDto {
  final String id;
  final String type; // e.g., 'profesor' or 'maton'
  final int position;

  BoardNpcDto({required this.id, required this.type, required this.position});

  factory BoardNpcDto.fromJson(Map<String, dynamic> json) {
    return BoardNpcDto(
      id: (json['id'] ?? json['npcId'])?.toString() ?? '',
      type: (json['type'] ?? json['role'] ?? 'npc')?.toString() ?? 'npc',
      position: (json['position'] as int?) ?? (json['pos'] as int?) ?? 0,
    );
  }
}

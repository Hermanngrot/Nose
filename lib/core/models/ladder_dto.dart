class LadderDto {
  final int bottomPosition;
  final int topPosition;

  LadderDto({required this.bottomPosition, required this.topPosition});

  factory LadderDto.fromJson(Map<String, dynamic> json) {
    return LadderDto(
      bottomPosition: (json['bottomPosition'] as int?) ?? (json['BottomPosition'] as int?) ?? (json['bottom'] as int?) ?? 0,
      topPosition: (json['topPosition'] as int?) ?? (json['TopPosition'] as int?) ?? (json['top'] as int?) ?? 0,
    );
  }
}

class SnakeDto {
  final int headPosition;
  final int tailPosition;

  SnakeDto({required this.headPosition, required this.tailPosition});

  factory SnakeDto.fromJson(Map<String, dynamic> json) {
    return SnakeDto(
      headPosition: (json['headPosition'] as int?) ?? (json['HeadPosition'] as int?) ?? (json['head'] as int?) ?? 0,
      tailPosition: (json['tailPosition'] as int?) ?? (json['TailPosition'] as int?) ?? (json['tail'] as int?) ?? 0,
    );
  }
}

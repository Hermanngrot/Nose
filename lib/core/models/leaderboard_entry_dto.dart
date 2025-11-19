class LeaderboardEntryDto {
  final String userId;
  final String username;
  final int wins;
  final int gamesPlayed;

  LeaderboardEntryDto({required this.userId, required this.username, required this.wins, required this.gamesPlayed});

  factory LeaderboardEntryDto.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryDto(
      userId: (json['userId'] ?? json['id'])?.toString() ?? '',
      username: json['username'] as String? ?? (json['name'] as String? ?? ''),
      wins: (json['wins'] as int?) ?? 0,
      gamesPlayed: (json['gamesPlayed'] as int?) ?? (json['played'] as int?) ?? 0,
    );
  }
}

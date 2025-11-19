import '../api_client.dart';
import '../models/leaderboard_entry_dto.dart';

class UserService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getMe() async {
    final resp = await _client.getJson('/api/Users/me');
    if (resp is Map) return Map<String, dynamic>.from(resp);
    return {};
  }

  Future<List<LeaderboardEntryDto>> getLeaderboard() async {
    final resp = await _client.getJson('/api/Users/leaderboard');
    dynamic data;
    if (resp is Map) {
      data = resp['leaderboard'] ?? resp['data'] ?? resp;
    } else {
      data = resp;
    }
    if (data is List) {
      return data.map((e) => LeaderboardEntryDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMyGames() async {
    final resp = await _client.getJson('/api/Users/me/games');
    dynamic data;
    if (resp is Map) {
      data = resp['games'] ?? resp['data'] ?? resp;
    } else {
      data = resp;
    }
    if (data is List) {
      // Ensure each element is a Map<String, dynamic>
      final out = <Map<String, dynamic>>[];
      for (final item in data) {
        if (item is Map) out.add(Map<String, dynamic>.from(item));
      }
      return out;
    }
    return [];
  }
}

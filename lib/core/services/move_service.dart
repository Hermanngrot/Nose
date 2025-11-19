import '../api_client.dart';
import '../models/move_result_dto.dart';
import '../models/profesor_question_dto.dart';

class MoveService {
  final ApiClient _client = ApiClient();

  Future<MoveResultDto> roll(String gameId) async {
    final resp = await _client.postJson('/api/Moves/roll', {'gameId': gameId});
    if (resp is Map) return MoveResultDto.fromJson(Map<String, dynamic>.from(resp));
    throw Exception('Unexpected roll response: ${resp.runtimeType}');
  }

  Future<ProfesorQuestionDto> getProfesor(String gameId) async {
    final resp = await _client.postJson('/api/Moves/get-profesor', {'gameId': gameId});
    if (resp is Map) return ProfesorQuestionDto.fromJson(Map<String, dynamic>.from(resp));
    throw Exception('Unexpected getProfesor response: ${resp.runtimeType}');
  }

  Future<MoveResultDto> answerProfesor(String gameId, String questionId, String answer) async {
    final resp = await _client.postJson('/api/Moves/answer-profesor', {'gameId': gameId, 'questionId': questionId, 'answer': answer});
    if (resp is Map) return MoveResultDto.fromJson(Map<String, dynamic>.from(resp));
    throw Exception('Unexpected answerProfesor response: ${resp.runtimeType}');
  }

  Future<void> surrender(String gameId) async {
    await _client.postJson('/api/Moves/surrender', {'gameId': gameId});
  }
}

import 'profesor_question_dto.dart';

class MoveResultDto {
  final int diceValue;
  final int fromPosition;
  final int toPosition;
  final int finalPosition;
  final String? specialEvent;
  final bool isWinner;
  final bool requiresProfesorAnswer;
  final String message;
  final dynamic profesorQuestionRaw;

  MoveResultDto({
    required this.diceValue,
    required this.fromPosition,
    required this.toPosition,
    required this.finalPosition,
    this.specialEvent,
    this.isWinner = false,
    this.requiresProfesorAnswer = false,
    this.message = '',
    this.profesorQuestionRaw,
  });

  // ============
  // COMPATIBILIDAD CON UI
  // ============
  int get dice => diceValue;
  int get newPosition => finalPosition;

  // ============
  // NUEVO: convertir profesorQuestionRaw a DTO
  // ============
  ProfesorQuestionDto? get profesorQuestion {
    if (profesorQuestionRaw == null) return null;
    if (profesorQuestionRaw is Map<String, dynamic>) {
      return ProfesorQuestionDto.fromJson(profesorQuestionRaw);
    }
    return null;
  }

  factory MoveResultDto.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is List && v.isNotEmpty) return parseInt(v.first);
      if (v is Map) {
        return parseInt(
          v['value'] ??
          v['dice'] ??
          v['diceValue'] ??
          v['position'] ??
          v['toPosition'] ??
          v['finalPosition']
        );
      }
      return 0;
    }

    bool parseBool(dynamic v, {bool defaultValue = false}) {
      if (v == null) return defaultValue;
      if (v is bool) return v;
      if (v is String) return (v.toLowerCase() == 'true' || v == '1');
      if (v is num) return v != 0;
      return defaultValue;
    }

    String parseString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }

    final diceVal = parseInt(json['diceValue'] ?? json['dice'] ?? json['roll']);
    final fromPos = parseInt(json['fromPosition'] ?? json['from']);
    final toPos = parseInt(json['toPosition'] ?? json['to']);
    final finalPos = parseInt(json['finalPosition'] ?? json['finalPos'] ?? json['toPosition'] ?? toPos);
    final spec = json['specialEvent']?.toString();
    final win = parseBool(json['isWinner']);
    final requires = parseBool(json['requiresProfesorAnswer']);
    final msg = parseString(json['message']);

    final profesorRaw = json['profesorQuestion'];

    return MoveResultDto(
      diceValue: diceVal,
      fromPosition: fromPos,
      toPosition: toPos,
      finalPosition: finalPos,
      specialEvent: spec,
      isWinner: win,
      requiresProfesorAnswer: requires,
      message: msg,
      profesorQuestionRaw: profesorRaw,
    );
  }
}

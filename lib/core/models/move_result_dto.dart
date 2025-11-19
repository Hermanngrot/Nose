class MoveResultDto {
  final int dice;
  final int newPosition;
  final bool moved;
  final String message;

  MoveResultDto({required this.dice, required this.newPosition, required this.moved, required this.message});

  factory MoveResultDto.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is List && v.isNotEmpty) return parseInt(v.first);
      if (v is Map) return parseInt(v['value'] ?? v['dice'] ?? v['roll'] ?? v['position']);
      return 0;
    }

    bool parseBool(dynamic v, {bool defaultValue = true}) {
      if (v == null) return defaultValue;
      if (v is bool) return v;
      if (v is String) return (v.toLowerCase() == 'true');
      if (v is num) return v != 0;
      return defaultValue;
    }

    String parseString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }

    final diceVal = parseInt(json['dice'] ?? json['roll'] ?? json['Roll'] ?? json['rolls'] ?? json['diceRoll']);
    final posVal = parseInt(json['newPosition'] ?? json['position'] ?? json['new_pos'] ?? json['pos']);
    final movedVal = parseBool(json['moved'] ?? json['movedSuccessfully'] ?? json['moved_ok'], defaultValue: true);
    final msgVal = parseString(json['message'] ?? json['msg'] ?? json['Message']);

    return MoveResultDto(
      dice: diceVal,
      newPosition: posVal,
      moved: movedVal,
      message: msgVal,
    );
  }
}

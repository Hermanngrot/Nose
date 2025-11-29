class ProfesorQuestionDto {
  /// Nombre del profesor (Huanca, Nancy, etc.)
  final String profesor;

  /// Ecuación / enunciado de la pregunta (por ejemplo "5x - 3 = 12")
  final String equation;

  /// Opciones de respuesta ya normalizadas a una lista de strings (valores: "x=4", "x=3", etc.)
  final List<String> options;
  
  /// Mapeo de letra a valor (A -> "x=4", B -> "x=3", etc.)
  final Map<String, String> optionsMap;

  ProfesorQuestionDto({
    required this.profesor,
    required this.equation,
    required this.options,
    required this.optionsMap,
  });

  /// Compatibilidad con el GameController:
  /// usamos la ecuación como "id" estable de la pregunta.
  String get questionId => equation;

  /// El texto de la pregunta que muestra el UI
  String get question => equation;
  
  /// Obtener la letra (A, B, C) correspondiente a un valor de respuesta
  String? getLetterForValue(String value) {
    for (final entry in optionsMap.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return null;
  }

  factory ProfesorQuestionDto.fromJson(Map<String, dynamic> json) {
    // El backend manda: Profesor, Equation, Options (diccionario A,B,C...)
    final profesor = (json['Profesor'] ?? json['profesor'] ?? '').toString();
    final equation = (json['Equation'] ?? json['equation'] ?? json['question'] ?? '').toString();

    // Options puede venir como diccionario o como lista
    List<String> opts = [];
    Map<String, String> optsMap = {};
    final rawOpts = json['Options'] ?? json['options'] ?? json['OptionsDict'];

    if (rawOpts is Map) {
      // Intentar respetar el orden A,B,C,D
      const keys = ['A', 'B', 'C', 'D'];
      for (final k in keys) {
        if (rawOpts.containsKey(k)) {
          final value = rawOpts[k].toString();
          opts.add(value);
          optsMap[k] = value; // Guardar mapeo letra -> valor
        }
      }
      if (opts.isEmpty) {
        opts = rawOpts.values.map((e) => e.toString()).toList();
        // Si no hay orden, crear mapeo genérico
        for (final entry in rawOpts.entries) {
          optsMap[entry.key.toString()] = entry.value.toString();
        }
      }
    } else if (rawOpts is List) {
      opts = rawOpts.map((e) => e.toString()).toList();
      // Crear mapeo A, B, C para lista sin keys
      const keys = ['A', 'B', 'C', 'D'];
      for (int i = 0; i < opts.length && i < keys.length; i++) {
        optsMap[keys[i]] = opts[i];
      }
    }

    return ProfesorQuestionDto(
      profesor: profesor,
      equation: equation,
      options: opts,
      optionsMap: optsMap,
    );
  }
}
class ProfesorQuestionDto {
  /// Nombre del profesor (Huanca, Nancy, etc.)
  final String profesor;

  /// Ecuación / enunciado de la pregunta (por ejemplo "5x - 3 = 12")
  final String equation;

  /// Opciones de respuesta ya normalizadas a una lista de strings
  final List<String> options;

  ProfesorQuestionDto({
    required this.profesor,
    required this.equation,
    required this.options,
  });

  /// Compatibilidad con el GameController:
  /// usamos la ecuación como "id" estable de la pregunta.
  String get questionId => equation;

  /// El texto de la pregunta que muestra el UI
  String get question => equation;

  factory ProfesorQuestionDto.fromJson(Map<String, dynamic> json) {
    // El backend manda: Profesor, Equation, Options (diccionario A,B,C...)
    final profesor = (json['Profesor'] ?? json['profesor'] ?? '').toString();
    final equation = (json['Equation'] ?? json['equation'] ?? json['question'] ?? '').toString();

    // Options puede venir como diccionario o como lista
    List<String> opts = [];
    final rawOpts = json['Options'] ?? json['options'] ?? json['OptionsDict'];

    if (rawOpts is Map) {
      // Intentar respetar el orden A,B,C,D
      const keys = ['A', 'B', 'C', 'D'];
      for (final k in keys) {
        if (rawOpts.containsKey(k)) {
          opts.add(rawOpts[k].toString());
        }
      }
      if (opts.isEmpty) {
        opts = rawOpts.values.map((e) => e.toString()).toList();
      }
    } else if (rawOpts is List) {
      opts = rawOpts.map((e) => e.toString()).toList();
    }

    return ProfesorQuestionDto(
      profesor: profesor,
      equation: equation,
      options: opts,
    );
  }
}
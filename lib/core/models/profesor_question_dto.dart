class ProfesorQuestionDto {
  final String? profesor; // backend may send Profesor
  final String? equation; // backend may send Equation
  final String questionId; // fallback id
  final String question;
  final List<String> options;

  ProfesorQuestionDto({this.profesor, this.equation, required this.questionId, required this.question, required this.options});

  factory ProfesorQuestionDto.fromJson(Map<String, dynamic> json) {
    // Backend may send fields: Profesor, Equation, Options (dictionary) or question/questionId/options
    final profesor = (json['Profesor'] ?? json['profesor'])?.toString();
    final equation = (json['Equation'] ?? json['equation'] ?? json['question'])?.toString();

    // Options might be a dictionary (A->text) or a list
    List<String> opts = [];
    final rawOpts = json['Options'] ?? json['options'] ?? json['OptionsDict'];
    if (rawOpts is Map) {
      // keep order A,B,C if present
      final keys = ['A', 'B', 'C', 'D'];
      for (var k in keys) {
        if (rawOpts.containsKey(k)) opts.add(rawOpts[k].toString());
      }
      if (opts.isEmpty) opts = rawOpts.values.map((e) => e.toString()).toList();
    } else if (rawOpts is List) {
      opts = rawOpts.map((e) => e.toString()).toList();
    }

    final qId = (json['questionId'] ?? json['id'] ?? '')?.toString() ?? '';
    final qText = (json['question'] ?? json['Equation'] ?? json['equation'] ?? '')?.toString() ?? '';

    return ProfesorQuestionDto(profesor: profesor, equation: equation, questionId: qId, question: qText, options: opts);
  }
}

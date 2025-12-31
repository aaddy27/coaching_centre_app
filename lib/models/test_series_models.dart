class TestSeries {
  final int id;
  final String title;
  final String description;
  final double price;
  final bool isFree;
  final bool isPurchased;
  final bool isAccessible;
  final List<TestSeriesSubject>? subjects;

  TestSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.isFree,
    required this.isPurchased,
    required this.isAccessible,
    this.subjects,
  });

  factory TestSeries.fromJson(Map<String, dynamic> json) {
    return TestSeries(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: _toDouble(json['price']),
      isFree: json['is_free'] ?? false,
      isPurchased: json['is_purchased'] ?? false,
      isAccessible: json['is_accessible'] ?? false,
      subjects: json['subjects'] != null
          ? (json['subjects'] as List)
                .map((e) => TestSeriesSubject.fromJson(e))
                .toList()
          : null,
    );
  }
}

class TestSeriesSubject {
  final int id;
  final String name;
  final int testCount;
  final bool isAccessible;

  TestSeriesSubject({
    required this.id,
    required this.name,
    this.testCount = 0,
    this.isAccessible = false,
  });

  factory TestSeriesSubject.fromJson(Map<String, dynamic> json) {
    return TestSeriesSubject(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      testCount: json['test_count'] ?? 0,
      isAccessible: json['is_accessible'] ?? false,
    );
  }
}

class TestInSeries {
  final int id;
  final String title;
  final int testNumber;
  final int duration;
  final double totalMarks;
  final double passingMarks;
  final double negativeMarking;
  final int questionsCount;
  final String? instructions;

  TestInSeries({
    required this.id,
    required this.title,
    required this.testNumber,
    required this.duration,
    required this.totalMarks,
    required this.passingMarks,
    required this.negativeMarking,
    required this.questionsCount,
    this.instructions,
  });

  factory TestInSeries.fromJson(Map<String, dynamic> json) {
    return TestInSeries(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      testNumber: json['test_number'] ?? 0,
      duration: json['duration'] ?? 0,
      totalMarks: _toDouble(json['total_marks']),
      passingMarks: _toDouble(json['passing_marks']),
      negativeMarking: _toDouble(json['negative_marking']),
      questionsCount: json['questions_count'] ?? 0,
      instructions: json['instructions'],
    );
  }
}

class TestQuestion {
  final int id;
  final String questionText;
  final String? questionImage;
  final Map<String, String> options;
  final double marks;
  final double negativeMarks;

  TestQuestion({
    required this.id,
    required this.questionText,
    this.questionImage,
    required this.options,
    required this.marks,
    required this.negativeMarks,
  });

  factory TestQuestion.fromJson(Map<String, dynamic> json) {
    return TestQuestion(
      id: json['id'] ?? 0,
      questionText: json['question_text'] ?? '',
      questionImage: json['question_image'],
      options: Map<String, String>.from(json['options'] ?? {}),
      marks: _toDouble(json['marks']),
      negativeMarks: _toDouble(json['negative_marks']),
    );
  }
}

// Helper to safely convert dynamic value to double
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

class TestSeries {
  final int id;
  final String title;
  final String description;
  final double price;
  final bool isFree;
  final bool isPurchased;
  final bool isAccessible;
  final int duration;
  final double totalMarks;
  final int questionsCount;
  final double rating;
  final int reviewsCount;
  final bool isCompleted;
  final List<TestSeriesSubject>? subjects;

  TestSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.isFree,
    required this.isPurchased,
    required this.isAccessible,
    this.duration = 0,
    this.totalMarks = 0.0,
    this.questionsCount = 0,
    this.rating = 4.8,
    this.reviewsCount = 42,
    this.isCompleted = false,
    this.subjects,
  });

  factory TestSeries.fromJson(Map<String, dynamic> json) {
    return TestSeries(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: _toDouble(json['price']),
      isFree: json['is_free'] ?? (json['price'] == null || _toDouble(json['price']) == 0.0),
      isPurchased: json['is_purchased'] ?? false,
      isAccessible: json['is_accessible'] ?? false,
      duration: json['duration'] is int
          ? json['duration']
          : (int.tryParse('${json['duration']}') ?? 0),
      totalMarks: _toDouble(json['total_marks']),
      questionsCount: json['questions_count'] is int
          ? json['questions_count']
          : (int.tryParse('${json['questions_count']}') ?? 0),
      rating: _toDouble(json['rating'] ?? 4.8),
      reviewsCount: json['reviews_count'] is int
          ? json['reviews_count']
          : 48,
      isCompleted: json['is_completed'] ?? false,
      subjects: json['subjects'] != null
          ? (json['subjects'] as List)
                .map((e) => TestSeriesSubject.fromJson(e))
                .toList()
          : null,
    );
  }

  TestSeries copyWith({
    int? id,
    String? title,
    String? description,
    double? price,
    bool? isFree,
    bool? isPurchased,
    bool? isAccessible,
    int? duration,
    double? totalMarks,
    int? questionsCount,
    double? rating,
    int? reviewsCount,
    bool? isCompleted,
    List<TestSeriesSubject>? subjects,
  }) {
    return TestSeries(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      isFree: isFree ?? this.isFree,
      isPurchased: isPurchased ?? this.isPurchased,
      isAccessible: isAccessible ?? this.isAccessible,
      duration: duration ?? this.duration,
      totalMarks: totalMarks ?? this.totalMarks,
      questionsCount: questionsCount ?? this.questionsCount,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isCompleted: isCompleted ?? this.isCompleted,
      subjects: subjects ?? this.subjects,
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

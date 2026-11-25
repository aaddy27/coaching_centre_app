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
    final id = _toInt(json['id']) ?? _toInt(json['test_series_id']) ?? 0;
    final price = _toDouble(json['price']);
    final isFree = json['is_free'] == true ||
        json['is_free'] == 1 ||
        (json['is_free'] == null && price == 0.0);
    final isPurchased = json['is_purchased'] == true || json['is_purchased'] == 1;
    final isAccessible =
        json['is_accessible'] == true || json['is_accessible'] == 1 || isPurchased;

    return TestSeries(
      id: id,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: price,
      isFree: isFree,
      isPurchased: isPurchased,
      isAccessible: isAccessible,
      duration: _toInt(json['duration_minutes']) ?? _toInt(json['duration']) ?? 0,
      totalMarks: _toDouble(json['total_marks']),
      questionsCount: _toInt(json['questions_count']) ?? 0,
      rating: json['rating'] != null ? _toDouble(json['rating']) : 4.8,
      reviewsCount: _toInt(json['reviews_count']) ?? 48,
      isCompleted: json['is_completed'] == true,
      subjects: json['subjects'] is List
          ? (json['subjects'] as List)
              .map((e) => TestSeriesSubject.fromJson(e, defaultAccessible: isAccessible))
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
  final int questionCount;
  final bool isAccessible;

  TestSeriesSubject({
    required this.id,
    required this.name,
    this.testCount = 0,
    this.questionCount = 0,
    this.isAccessible = false,
  });

  factory TestSeriesSubject.fromJson(
    Map<String, dynamic> json, {
    bool defaultAccessible = false,
  }) {
    return TestSeriesSubject(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      testCount: _toInt(json['tests_count']) ?? _toInt(json['test_count']) ?? 0,
      questionCount:
          _toInt(json['question_count']) ?? _toInt(json['questions_count']) ?? 0,
      isAccessible: json['is_accessible'] == true || defaultAccessible,
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
      id: _toInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      testNumber: _toInt(json['test_number']) ?? 0,
      duration: _toInt(json['duration']) ?? _toInt(json['duration_minutes']) ?? 0,
      totalMarks: _toDouble(json['total_marks']),
      passingMarks: _toDouble(json['passing_marks']),
      negativeMarking: _toDouble(json['negative_marking']),
      questionsCount: _toInt(json['questions_count']) ?? 0,
      instructions: json['instructions']?.toString(),
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
    final rawOptions = json['options'];
    final parsedOptions = <String, String>{};
    if (rawOptions is Map) {
      rawOptions.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          parsedOptions[key.toString()] = value.toString();
        }
      });
    }

    return TestQuestion(
      id: _toInt(json['id']) ?? 0,
      questionText: json['question_text']?.toString() ?? '',
      questionImage:
          json['question_image_url']?.toString() ??
          json['question_image']?.toString(),
      options: parsedOptions,
      marks: _toDouble(json['marks']),
      negativeMarks: _toDouble(json['negative_marks']),
    );
  }
}

class QuestionResultDetail {
  final int questionId;
  final String questionText;
  final String? userAnswer;
  final String? correctAnswer;
  final bool isCorrect;
  final double marksObtained;
  final String? explanation;

  QuestionResultDetail({
    required this.questionId,
    required this.questionText,
    this.userAnswer,
    this.correctAnswer,
    required this.isCorrect,
    required this.marksObtained,
    this.explanation,
  });

  factory QuestionResultDetail.fromJson(Map<String, dynamic> json) {
    return QuestionResultDetail(
      questionId: _toInt(json['question_id']) ?? 0,
      questionText: json['question_text']?.toString() ?? '',
      userAnswer: json['user_answer']?.toString(),
      correctAnswer: json['correct_answer']?.toString(),
      isCorrect: json['is_correct'] == true || json['is_correct'] == 1,
      marksObtained: _toDouble(json['marks_obtained']),
      explanation: json['explanation']?.toString(),
    );
  }
}

class TestReport {
  final int attemptId;
  final String? testTitle;
  final double score;
  final double? totalMarks;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final int durationMinutes;
  final List<QuestionResultDetail> detailedResults;

  TestReport({
    required this.attemptId,
    this.testTitle,
    required this.score,
    this.totalMarks,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unansweredCount,
    required this.durationMinutes,
    required this.detailedResults,
  });

  factory TestReport.fromJson(Map<String, dynamic> json) {
    final resultsList = json['detailed_results'] is List
        ? (json['detailed_results'] as List)
            .map((e) => QuestionResultDetail.fromJson(e))
            .toList()
        : <QuestionResultDetail>[];

    return TestReport(
      attemptId: _toInt(json['attempt_id']) ?? _toInt(json['id']) ?? 0,
      testTitle: json['test_title']?.toString() ??
          (json['test'] is Map ? json['test']['title']?.toString() : null),
      score: _toDouble(json['score']),
      totalMarks: json['total_marks'] != null ? _toDouble(json['total_marks']) : null,
      totalQuestions: _toInt(json['total_questions']) ?? resultsList.length,
      correctCount: _toInt(json['correct_count']) ?? 0,
      incorrectCount: _toInt(json['incorrect_count']) ?? 0,
      unansweredCount: _toInt(json['unanswered_count']) ?? 0,
      durationMinutes: _toInt(json['duration_minutes']) ?? 0,
      detailedResults: resultsList,
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

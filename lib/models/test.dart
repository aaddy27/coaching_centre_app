class Test {
  final int id;
  final String title;
  final String? description;
  final String? instructions;
  final int duration; // in minutes
  final int totalMarks;
  final int passingMarks;
  final int totalQuestions;
  final bool negativeMarking;
  final double? negativeMarks;
  final int? attemptsAllowed;
  final int? yourAttempts;
  final bool isPublished;
  final Course? course;

  Test({
    required this.id,
    required this.title,
    this.description,
    this.instructions,
    required this.duration,
    required this.totalMarks,
    required this.passingMarks,
    required this.totalQuestions,
    required this.negativeMarking,
    this.negativeMarks,
    this.attemptsAllowed,
    this.yourAttempts,
    required this.isPublished,
    this.course,
  });

  factory Test.fromJson(Map<String, dynamic> json) {
    return Test(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      instructions: json['instructions'],
      duration: json['duration'] ?? 0,
      totalMarks: json['total_marks'] ?? 0,
      passingMarks: json['passing_marks'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      negativeMarking: json['negative_marking'] ?? false,
      negativeMarks: json['negative_marks']?.toDouble(),
      attemptsAllowed: json['attempts_allowed'],
      yourAttempts: json['your_attempts'],
      isPublished: json['is_published'] ?? false,
      course: json['course'] != null 
          ? Course.fromJson(json['course']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructions': instructions,
      'duration': duration,
      'total_marks': totalMarks,
      'passing_marks': passingMarks,
      'total_questions': totalQuestions,
      'negative_marking': negativeMarking,
      'negative_marks': negativeMarks,
      'attempts_allowed': attemptsAllowed,
      'your_attempts': yourAttempts,
      'is_published': isPublished,
      'course': course?.toJson(),
    };
  }
}

class Course {
  final int id;
  final String title;
  final String? thumbnail;

  Course({
    required this.id,
    required this.title,
    this.thumbnail,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
    };
  }
}

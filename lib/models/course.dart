import 'package:flutter/foundation.dart';

class Course {
  final int id;
  final int? examBoardId;
  final String title;
  final String slug;
  final String description;
  final String? shortDescription;
  final double price;
  final String currency;
  final String? duration;
  final String? level;
  final String? language;
  final String? thumbnail;
  final String? thumbnailPath;
  final String? previewVideo;
  final bool isPublished;
  final bool isPurchased;
  final int? totalVideos;
  final int? totalTests;
  final int? enrolledStudents;
  final int? totalSubjects;
  final String? totalDuration;
  final int? progress;
  final int? completedVideos;
  final DateTime? enrolledAt;
  final DateTime? createdAt;
  final ExamBoard? examBoard;
  final List<CourseSubject>? subjects;

  Course({
    required this.id,
    this.examBoardId,
    required this.title,
    required this.slug,
    required this.description,
    this.shortDescription,
    required this.price,
    required this.currency,
    this.duration,
    this.level,
    this.language,
    this.thumbnail,
    this.thumbnailPath,
    this.previewVideo,
    required this.isPublished,
    this.isPurchased = false,
    this.totalVideos,
    this.totalTests,
    this.enrolledStudents,
    this.totalSubjects,
    this.totalDuration,
    this.progress,
    this.completedVideos,
    this.enrolledAt,
    this.createdAt,
    this.examBoard,
    this.subjects,
  });

  String? get effectiveThumbnail {
    if (thumbnail != null && thumbnail!.isNotEmpty) return thumbnail;
    if (thumbnailPath != null && thumbnailPath!.isNotEmpty) {
      return thumbnailPath;
    }
    return null;
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    try {
      return Course(
        id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
        examBoardId: _parseInt(json['exam_board_id']),
        title: json['title']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        shortDescription: json['short_description']?.toString(),
        price: _parseDouble(json['price']),
        currency: json['currency']?.toString() ?? 'INR',
        duration: json['duration']?.toString(),
        level: json['level']?.toString(),
        language: json['language']?.toString(),
        thumbnail: json['thumbnail']?.toString() ?? json['thumbnail_path']?.toString(),
        thumbnailPath: json['thumbnail_path']?.toString(),
        previewVideo: json['preview_video']?.toString(),
        isPublished: json['is_published'] == true || json['is_published'] == 1 || json['is_published'] == '1',
        isPurchased: json['is_purchased'] == true ||
            json['has_purchased'] == true ||
            json['is_enrolled'] == true,
        totalVideos: _parseInt(json['total_videos']) ?? _parseInt(json['videos_count']),
        totalTests: _parseInt(json['total_tests']),
        enrolledStudents: _parseInt(json['enrolled_students']),
        totalSubjects: json['subjects'] != null
            ? (json['subjects'] as List).length
            : _parseInt(json['total_subjects']),
        totalDuration: json['total_duration']?.toString(),
        progress: _parseInt(json['progress']),
        completedVideos: _parseInt(json['completed_videos']),
        enrolledAt: json['enrolled_at'] != null
            ? DateTime.tryParse(json['enrolled_at'].toString())
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        examBoard: json['exam_board'] != null
            ? ExamBoard.fromJson(json['exam_board'])
            : null,
        subjects: json['subjects'] != null
            ? (json['subjects'] as List).map((s) => CourseSubject.fromJson(s)).toList()
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing course: $e');
      rethrow;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_board_id': examBoardId,
      'title': title,
      'slug': slug,
      'description': description,
      'short_description': shortDescription,
      'price': price,
      'currency': currency,
      'duration': duration,
      'level': level,
      'language': language,
      'thumbnail': thumbnail,
      'thumbnail_path': thumbnailPath,
      'preview_video': previewVideo,
      'is_published': isPublished,
      'total_videos': totalVideos,
      'total_tests': totalTests,
      'enrolled_students': enrolledStudents,
      'total_subjects': totalSubjects,
      'total_duration': totalDuration,
      'progress': progress,
      'completed_videos': completedVideos,
      'enrolled_at': enrolledAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'exam_board': examBoard?.toJson(),
      'subjects': subjects?.map((s) => s.toJson()).toList(),
    };
  }
}

class ExamBoard {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExamBoard({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory ExamBoard.fromJson(Map<String, dynamic> json) {
    return ExamBoard(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class CourseSubject {
  final int id;
  final int? examId;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;
  final int? videosCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CourseSubject({
    required this.id,
    this.examId,
    required this.name,
    required this.slug,
    this.description,
    required this.isActive,
    this.videosCount,
    this.createdAt,
    this.updatedAt,
  });

  factory CourseSubject.fromJson(Map<String, dynamic> json) {
    return CourseSubject(
      id: json['id'] ?? 0,
      examId: json['exam_id'],
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      videosCount: json['videos_count'] is int 
          ? json['videos_count'] 
          : int.tryParse(json['videos_count']?.toString() ?? ''),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'name': name,
      'slug': slug,
      'description': description,
      'is_active': isActive,
      'videos_count': videosCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Subject {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final int totalVideos;
  final String? totalDuration;
  final int completedVideos;
  final int progressPercentage;
  final String? thumbnail;
  final int order;

  Subject({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.totalVideos,
    this.totalDuration,
    required this.completedVideos,
    required this.progressPercentage,
    this.thumbnail,
    required this.order,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      totalVideos: json['total_videos'] ?? 0,
      totalDuration: json['total_duration'],
      completedVideos: json['completed_videos'] ?? 0,
      progressPercentage: json['progress_percentage'] ?? 0,
      thumbnail: json['thumbnail'],
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'total_videos': totalVideos,
      'total_duration': totalDuration,
      'completed_videos': completedVideos,
      'progress_percentage': progressPercentage,
      'thumbnail': thumbnail,
      'order': order,
    };
  }
}

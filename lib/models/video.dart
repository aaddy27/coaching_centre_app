class Video {
  final int id;
  final String title;
  final String? description;
  final int order;
  final String? duration;
  final int? durationSeconds;
  final double? sizeMb;
  final String? thumbnail;
  final String videoType; // upload, vimeo, youtube
  final String? videoUrl;
  final String? vimeoId;
  final String? youtubeId;
  final bool? isPreview;
  final bool? isFree;
  final String? status; // ready, processing, pending, failed
  final int? views;
  final bool isWatched;
  final int watchProgress;
  final DateTime? lastWatchedAt;
  final List<QualityOption>? qualityOptions;

  Video({
    required this.id,
    required this.title,
    this.description,
    required this.order,
    this.duration,
    this.durationSeconds,
    this.sizeMb,
    this.thumbnail,
    required this.videoType,
    this.videoUrl,
    this.vimeoId,
    this.youtubeId,
    this.isPreview,
    this.isFree,
    this.status,
    this.views,
    required this.isWatched,
    required this.watchProgress,
    this.lastWatchedAt,
    this.qualityOptions,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      order: json['order'] ?? 0,
      duration: json['duration'],
      durationSeconds: json['duration_seconds'],
      sizeMb: json['size_mb']?.toDouble(),
      thumbnail: json['thumbnail'],
      videoType: json['video_type'] ?? 'upload',
      videoUrl: json['video_url'],
      vimeoId: json['vimeo_id'],
      youtubeId: json['youtube_id'],
      isPreview: json['is_preview'],
      isFree: json['is_free'],
      status: json['status'],
      views: json['views'],
      isWatched: json['is_watched'] ?? false,
      watchProgress: json['watch_progress'] ?? 0,
      lastWatchedAt: json['last_watched_at'] != null
          ? DateTime.tryParse(json['last_watched_at'])
          : null,
      qualityOptions: json['quality_options'] != null
          ? (json['quality_options'] as List)
              .map((q) => QualityOption.fromJson(q))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'order': order,
      'duration': duration,
      'duration_seconds': durationSeconds,
      'size_mb': sizeMb,
      'thumbnail': thumbnail,
      'video_type': videoType,
      'video_url': videoUrl,
      'vimeo_id': vimeoId,
      'youtube_id': youtubeId,
      'is_preview': isPreview,
      'is_free': isFree,
      'status': status,
      'views': views,
      'is_watched': isWatched,
      'watch_progress': watchProgress,
      'last_watched_at': lastWatchedAt?.toIso8601String(),
      'quality_options': qualityOptions?.map((q) => q.toJson()).toList(),
    };
  }
}

class QualityOption {
  final String label;
  final double? sizeMb;
  final String? url;

  QualityOption({
    required this.label,
    this.sizeMb,
    this.url,
  });

  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      label: json['label'] ?? '',
      sizeMb: json['size_mb']?.toDouble(),
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'size_mb': sizeMb,
      'url': url,
    };
  }
}

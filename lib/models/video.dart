class Video {
  final int id;
  final int? subjectId;
  final int? courseId;
  final String title;
  final String? description;
  final int order;
  final String? duration;
  final String? durationFormatted;
  final int? durationSeconds;
  final double? sizeMb;
  final String? thumbnail;
  final String videoType; // upload, vimeo, youtube
  final String? videoUrl;
  final String? vimeoId;
  final String? youtubeId;
  final bool? isPreview;
  final bool? isFree;
  final bool canPlay;
  final bool requiresPurchase;
  final int? viewLimit;
  final String? status;
  final int? views;
  final bool isWatched;
  final int watchProgress;
  final int watchedSeconds;
  final DateTime? lastWatchedAt;
  final List<QualityOption>? qualityOptions;

  Video({
    required this.id,
    this.subjectId,
    this.courseId,
    required this.title,
    this.description,
    required this.order,
    this.duration,
    this.durationFormatted,
    this.durationSeconds,
    this.sizeMb,
    this.thumbnail,
    required this.videoType,
    this.videoUrl,
    this.vimeoId,
    this.youtubeId,
    this.isPreview,
    this.isFree,
    this.canPlay = false,
    this.requiresPurchase = false,
    this.viewLimit,
    this.status,
    this.views,
    required this.isWatched,
    required this.watchProgress,
    this.watchedSeconds = 0,
    this.lastWatchedAt,
    this.qualityOptions,
  });

  Video copyWithProgress({
    bool? isWatched,
    int? watchProgress,
    int? watchedSeconds,
  }) {
    return Video(
      id: id,
      subjectId: subjectId,
      courseId: courseId,
      title: title,
      description: description,
      order: order,
      duration: duration,
      durationFormatted: durationFormatted,
      durationSeconds: durationSeconds,
      sizeMb: sizeMb,
      thumbnail: thumbnail,
      videoType: videoType,
      videoUrl: videoUrl,
      vimeoId: vimeoId,
      youtubeId: youtubeId,
      isPreview: isPreview,
      isFree: isFree,
      canPlay: canPlay,
      requiresPurchase: requiresPurchase,
      viewLimit: viewLimit,
      status: status,
      views: views,
      isWatched: isWatched ?? this.isWatched,
      watchProgress: watchProgress ?? this.watchProgress,
      watchedSeconds: watchedSeconds ?? this.watchedSeconds,
      lastWatchedAt: lastWatchedAt,
      qualityOptions: qualityOptions,
    );
  }

  String? get displayDuration {
    if (durationFormatted != null && durationFormatted!.isNotEmpty) {
      return durationFormatted;
    }
    if (duration != null && duration!.isNotEmpty) {
      return duration;
    }
    if (durationSeconds != null && durationSeconds! > 0) {
      final mins = (durationSeconds! / 60).round();
      return '$mins mins';
    }
    return null;
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    String videoType = json['video_type']?.toString() ?? 'upload';
    final videoUrl = json['video_url']?.toString();

    if (videoType == 'upload' && videoUrl != null) {
      if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
        videoType = 'youtube';
      } else if (videoUrl.contains('vimeo.com')) {
        videoType = 'vimeo';
      }
    }

    final isPreviewVal = _parseBool(json['is_preview']);
    final isFreeVal = _parseBool(json['is_free']);
    final requiresPurchaseVal = _parseBool(json['requires_purchase']) ?? false;
    final canPlayVal = _parseBool(json['can_play']) ??
        ((isPreviewVal == true || isFreeVal == true) && !requiresPurchaseVal);

    return Video(
      id: _parseInt(json['id']) ?? 0,
      subjectId: _parseInt(json['subject_id']) ??
          (json['subject'] is Map ? _parseInt(json['subject']['id']) : null),
      courseId: _parseInt(json['course_id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      order: _parseInt(json['order']) ?? _parseInt(json['sort_order']) ?? 0,
      duration: json['duration']?.toString(),
      durationFormatted: json['duration_formatted']?.toString(),
      durationSeconds: _parseInt(json['duration_seconds']),
      sizeMb: _parseDouble(json['size_mb']),
      thumbnail: json['thumbnail']?.toString(),
      videoType: videoType,
      videoUrl: videoUrl,
      vimeoId: json['vimeo_id']?.toString(),
      youtubeId: json['youtube_id']?.toString(),
      isPreview: isPreviewVal,
      isFree: isFreeVal,
      canPlay: canPlayVal,
      requiresPurchase: requiresPurchaseVal,
      viewLimit: _parseInt(json['view_limit']),
      status: json['status']?.toString(),
      views: _parseInt(json['views']),
      isWatched: _parseBool(json['is_watched']) ?? false,
      watchProgress: _parseInt(json['watch_progress']) ?? 0,
      watchedSeconds: _parseInt(json['watched_seconds']) ?? 0,
      lastWatchedAt: json['last_watched_at'] != null
          ? DateTime.tryParse(json['last_watched_at'].toString())
          : null,
      qualityOptions: json['quality_options'] is List
          ? (json['quality_options'] as List)
              .map((q) => QualityOption.fromJson(q))
              .toList()
          : null,
    );
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString());
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  static bool? _parseBool(dynamic val) {
    if (val == null) return null;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) return val == 'true' || val == '1';
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'order': order,
      'duration': duration,
      'duration_formatted': durationFormatted,
      'duration_seconds': durationSeconds,
      'size_mb': sizeMb,
      'thumbnail': thumbnail,
      'video_type': videoType,
      'video_url': videoUrl,
      'vimeo_id': vimeoId,
      'youtube_id': youtubeId,
      'is_preview': isPreview,
      'is_free': isFree,
      'can_play': canPlay,
      'requires_purchase': requiresPurchase,
      'view_limit': viewLimit,
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
      label: json['label']?.toString() ?? '',
      sizeMb: json['size_mb'] is num ? (json['size_mb'] as num).toDouble() : null,
      url: json['url']?.toString(),
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

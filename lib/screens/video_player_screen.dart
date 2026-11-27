import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video.dart';
import '../registration/login_screen.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;
  final List<Video>? playlist;
  final String? courseTitle;
  final int? courseId;
  final bool hasPurchased;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.playlist,
    this.courseTitle,
    this.courseId,
    this.hasPurchased = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late Video _currentVideo;
  late List<Video> _playlist;

  bool _isLoading = true;
  bool _requiresPurchase = false;
  bool _requiresLogin = false;
  String? _errorMessage;

  String? _videoUrl;
  String _videoType = 'upload';
  double _playbackSpeed = 1.0;

  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;

  // Player UI state
  bool _showControls = true;
  bool _isDraggingSlider = false;
  double _dragSliderValue = 0.0;
  Timer? _hideControlsTimer;
  Timer? _progressSyncTimer;
  Timer? _upNextTimer;
  int _upNextCountdown = 0;
  String? _seekFeedback;
  Timer? _seekFeedbackTimer;
  bool _resumedNoticeShown = false;

  // Live progress state
  int _watchProgress = 0;
  int _watchedSeconds = 0;
  bool _isCompleted = false;
  Map<int, Map<String, dynamic>> _localProgressMap = {};
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    _playlist = widget.playlist != null && widget.playlist!.isNotEmpty
        ? List<Video>.from(widget.playlist!)
        : [widget.video];
    _loadInitialProgressAndStream();
  }

  Future<void> _loadInitialProgressAndStream() async {
    _localProgressMap = await ApiService.getLocalVideoProgressMap();
    _hydrateVideoProgress(_currentVideo);
    await _loadVideoStream();
  }

  void _hydrateVideoProgress(Video video) {
    final local = _localProgressMap[video.id];
    final localProgress =
        local?['progress'] is int ? local!['progress'] as int : 0;
    final localSeconds =
        local?['watched_seconds'] is int ? local!['watched_seconds'] as int : 0;
    final localCompleted = local?['completed'] == true;

    _watchProgress = localProgress > video.watchProgress
        ? localProgress
        : video.watchProgress;
    _watchedSeconds = localSeconds > video.watchedSeconds
        ? localSeconds
        : video.watchedSeconds;
    _isCompleted =
        video.isWatched || localCompleted || _watchProgress >= 90;
  }

  Future<void> _disposePlayers() async {
    _hideControlsTimer?.cancel();
    _progressSyncTimer?.cancel();
    _upNextTimer?.cancel();
    _seekFeedbackTimer?.cancel();

    _youtubeController?.dispose();
    _youtubeController = null;

    final vp = _videoPlayerController;
    _videoPlayerController = null;
    if (vp != null) {
      vp.removeListener(_onVideoTick);
      await vp.dispose();
    }
  }

  Future<void> _loadVideoStream() async {
    await _saveCurrentProgress(force: true);
    await _disposePlayers();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _requiresPurchase = false;
      _requiresLogin = false;
      _upNextCountdown = 0;
      _resumedNoticeShown = false;
    });

    try {
      final loggedIn = await ApiService.isLoggedIn();

      if (loggedIn) {
        final response = await ApiService.streamVideo(_currentVideo.id);
        if (!mounted) return;

        if (response['success'] == true && response['data'] != null) {
          final videoMap =
              response['data']['video'] as Map<String, dynamic>? ??
                  response['data'] as Map<String, dynamic>;
          _videoUrl =
              videoMap['video_url']?.toString() ?? _currentVideo.videoUrl;
          _videoType =
              videoMap['video_type']?.toString() ?? _currentVideo.videoType;
        } else {
          final statusCode = response['status_code'];
          final reqPurchase =
              response['data']?['requires_purchase'] == true ||
                  response['requires_purchase'] == true;
          setState(() {
            _requiresPurchase = reqPurchase || statusCode == 403;
            _requiresLogin = statusCode == 401;
            _errorMessage = ApiService.extractErrorMessage(
              response,
              fallback: 'Unable to load video stream.',
            );
            _isLoading = false;
          });
          return;
        }
      } else if (_currentVideo.videoUrl != null &&
          _currentVideo.videoUrl!.isNotEmpty &&
          (_currentVideo.isPreview == true || _currentVideo.isFree == true)) {
        _videoUrl = _currentVideo.videoUrl;
        _videoType = _currentVideo.videoType;
      } else {
        setState(() {
          _requiresLogin = true;
          _errorMessage = 'Please sign in to stream this lecture.';
          _isLoading = false;
        });
        return;
      }

      await _initializePlayer();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final isForbidden = raw.contains('-12660') ||
          raw.contains('403') ||
          raw.toLowerCase().contains('do not have permission');
      setState(() {
        _errorMessage = isForbidden
            ? 'This video stream is currently unreachable (server returned 403 Access Denied). Please contact support or try another lecture.'
            : 'Unable to play this video right now. Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializePlayer() async {
    final url = _videoUrl;
    if (url == null || url.isEmpty) {
      setState(() {
        _errorMessage = 'Stream URL is unavailable for this video.';
        _isLoading = false;
      });
      return;
    }

    // YouTube stream
    if (_videoType == 'youtube' ||
        url.contains('youtube.com') ||
        url.contains('youtu.be')) {
      final ytId =
          YoutubePlayer.convertUrlToId(url) ?? _currentVideo.youtubeId;
      if (ytId != null && ytId.isNotEmpty) {
        _videoType = 'youtube';
        _youtubeController = YoutubePlayerController(
          initialVideoId: ytId,
          flags: YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            enableCaption: true,
            startAt: _watchedSeconds > 5 && !_isCompleted ? _watchedSeconds : 0,
          ),
        );
        _startYoutubeProgressTimer();
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    // Standard MP4 / HLS stream via video_player
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoPlayerController = controller;
    await controller.initialize();
    if (!mounted) return;

    final totalSecs = controller.value.duration.inSeconds;
    if (_watchedSeconds > 5 &&
        totalSecs > 15 &&
        _watchedSeconds < (totalSecs * 0.92).round()) {
      await controller.seekTo(Duration(seconds: _watchedSeconds));
      _resumedNoticeShown = true;
    }

    await controller.setPlaybackSpeed(_playbackSpeed);
    await controller.play();

    controller.addListener(_onVideoTick);
    _startProgressSyncTimer();
    _resetHideControlsTimer();

    // Save initial watch entry immediately so Home Continue Watching picks it up
    await ApiService.saveLocalVideoProgress(
      videoId: _currentVideo.id,
      progress: _watchProgress > 0 ? _watchProgress : 1,
      watchedSeconds: _watchedSeconds > 0 ? _watchedSeconds : 1,
      completed: _isCompleted,
      courseId: widget.courseId ?? _currentVideo.courseId,
      courseTitle: widget.courseTitle,
      videoJson: _currentVideo.toJson(),
      syncRemote: false,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _showControls = true;
      });
      if (_resumedNoticeShown) {
        showIosToast(
          context,
          title: 'Resumed Lecture',
          message: 'Continuing from ${_formatDuration(Duration(seconds: _watchedSeconds))}',
          icon: CupertinoIcons.play_circle_fill,
          iconColor: IosTheme.primaryBlue,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  void _onVideoTick() {
    if (!mounted) return;
    final vp = _videoPlayerController;
    if (vp == null || !vp.value.isInitialized) return;

    final durationMs = vp.value.duration.inMilliseconds;
    final posMs = vp.value.position.inMilliseconds;

    if (durationMs > 0) {
      final pct = ((posMs / durationMs) * 100).round().clamp(0, 100);
      final secs = vp.value.position.inSeconds;
      final completedNow = pct >= 92 ||
          (vp.value.isCompleted) ||
          (durationMs - posMs <= 800 && posMs > 0);

      if (pct != _watchProgress || secs != _watchedSeconds || (completedNow && !_isCompleted)) {
        setState(() {
          _watchedSeconds = secs;
          if (pct > _watchProgress) _watchProgress = pct;
          if (completedNow) {
            _isCompleted = true;
            _watchProgress = 100;
          }
        });
      }

      if (completedNow && _upNextCountdown == 0 && _nextUnlockedVideo != null) {
        _saveCurrentProgress(force: true);
        _startUpNextCountdown();
      }
    } else {
      setState(() {});
    }
  }

  void _startProgressSyncTimer() {
    _progressSyncTimer?.cancel();
    _progressSyncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _saveCurrentProgress();
    });
  }

  void _startYoutubeProgressTimer() {
    _progressSyncTimer?.cancel();
    _progressSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final yt = _youtubeController;
      if (yt == null || !mounted) return;
      final pos = yt.value.position.inSeconds;
      final dur = yt.metadata.duration.inSeconds;
      if (dur > 0) {
        final pct = ((pos / dur) * 100).round().clamp(0, 100);
        setState(() {
          _watchedSeconds = pos;
          if (pct > _watchProgress) _watchProgress = pct;
          if (pct >= 92) {
            _isCompleted = true;
            _watchProgress = 100;
          }
        });
        _saveCurrentProgress();
      }
    });
  }

  Future<void> _saveCurrentProgress({bool force = false}) async {
    if (_currentVideo.id <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSyncTime).inSeconds < 4) return;
    if (_watchedSeconds <= 0 && _watchProgress <= 0 && !_isCompleted) return;

    _lastSyncTime = now;
    await ApiService.saveLocalVideoProgress(
      videoId: _currentVideo.id,
      progress: _isCompleted ? 100 : _watchProgress,
      watchedSeconds: _watchedSeconds,
      completed: _isCompleted,
      courseId: widget.courseId ?? _currentVideo.courseId,
      courseTitle: widget.courseTitle,
      videoJson: _currentVideo.toJson(),
    );
    _localProgressMap[_currentVideo.id] = {
      'progress': _isCompleted ? 100 : _watchProgress,
      'watched_seconds': _watchedSeconds,
      'completed': _isCompleted,
    };
  }

  void _startUpNextCountdown() {
    if (_nextUnlockedVideo == null) return;
    _upNextTimer?.cancel();
    setState(() => _upNextCountdown = 5);
    _upNextTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_upNextCountdown <= 1) {
        t.cancel();
        final next = _nextUnlockedVideo;
        if (next != null) _switchToVideo(next);
      } else {
        setState(() => _upNextCountdown--);
      }
    });
  }

  void _cancelUpNext() {
    _upNextTimer?.cancel();
    if (mounted) setState(() => _upNextCountdown = 0);
  }

  int get _currentIndex =>
      _playlist.indexWhere((v) => v.id == _currentVideo.id);

  bool _canPlayVideo(Video v) {
    return widget.hasPurchased ||
        v.canPlay ||
        v.isPreview == true ||
        v.isFree == true;
  }

  Video? get _prevUnlockedVideo {
    final idx = _currentIndex;
    for (int i = idx - 1; i >= 0; i--) {
      if (_canPlayVideo(_playlist[i])) return _playlist[i];
    }
    return null;
  }

  Video? get _nextUnlockedVideo {
    final idx = _currentIndex;
    if (idx < 0) return null;
    for (int i = idx + 1; i < _playlist.length; i++) {
      if (_canPlayVideo(_playlist[i])) return _playlist[i];
    }
    return null;
  }

  Future<void> _switchToVideo(Video video) async {
    if (video.id == _currentVideo.id) return;
    if (!_canPlayVideo(video)) {
      showIosToast(
        context,
        title: 'Lecture Locked',
        message: 'Enroll in this course to unlock this lecture.',
        icon: CupertinoIcons.lock_fill,
        iconColor: IosTheme.systemOrange,
      );
      return;
    }
    HapticFeedback.selectionClick();
    await _saveCurrentProgress(force: true);
    setState(() {
      _currentVideo = video;
      _hydrateVideoProgress(video);
    });
    await _loadVideoStream();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_videoPlayerController?.value.isPlaying == true) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls && !_isDraggingSlider) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideControlsTimer();
  }

  Future<void> _togglePlayPause() async {
    final vp = _videoPlayerController;
    if (vp == null || !vp.value.isInitialized) return;
    HapticFeedback.lightImpact();
    _cancelUpNext();
    if (vp.value.isPlaying) {
      await vp.pause();
      await _saveCurrentProgress(force: true);
      setState(() => _showControls = true);
    } else {
      await vp.play();
      _resetHideControlsTimer();
    }
    setState(() {});
  }

  Future<void> _seekBy(int seconds) async {
    final vp = _videoPlayerController;
    if (vp == null || !vp.value.isInitialized) return;
    HapticFeedback.lightImpact();
    _cancelUpNext();
    final current = vp.value.position;
    final total = vp.value.duration;
    var target = current + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;
    await vp.seekTo(target);
    _resetHideControlsTimer();

    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekFeedback = seconds > 0 ? '+${seconds}s' : '${seconds}s';
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
  }

  void _showSpeedPicker() {
    const speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: const Text('Playback Speed'),
        message: const Text('Adjust lecture playback speed'),
        actions: speeds.map((s) {
          final isSelected = (_playbackSpeed - s).abs() < 0.01;
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetCtx);
              setState(() => _playbackSpeed = s);
              await _videoPlayerController?.setPlaybackSpeed(s);
              _youtubeController?.setPlaybackRate(s);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${s == s.toInt() ? s.toInt() : s}x${s == 1.0 ? ' (Normal)' : ''}',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? IosTheme.primaryBlue
                        : IosTheme.labelPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.checkmark_alt,
                    size: 18,
                    color: IosTheme.primaryBlue,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetCtx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _toggleCompletedManually() async {
    HapticFeedback.mediumImpact();
    final nextState = !_isCompleted;
    setState(() {
      _isCompleted = nextState;
      _watchProgress = nextState ? 100 : (_watchProgress >= 90 ? 50 : _watchProgress);
    });
    await ApiService.saveLocalVideoProgress(
      videoId: _currentVideo.id,
      progress: _watchProgress,
      watchedSeconds: _watchedSeconds,
      completed: _isCompleted,
      courseId: widget.courseId ?? _currentVideo.courseId,
      courseTitle: widget.courseTitle,
      videoJson: _currentVideo.toJson(),
    );
    _localProgressMap[_currentVideo.id] = {
      'progress': _watchProgress,
      'watched_seconds': _watchedSeconds,
      'completed': _isCompleted,
    };
    if (!mounted) return;
    showIosToast(
      context,
      title: _isCompleted ? 'Lecture Completed' : 'Marked Incomplete',
      message: _isCompleted
          ? 'Your course progress has been updated.'
          : 'Lecture unmarked from completed list.',
      icon: _isCompleted
          ? CupertinoIcons.checkmark_alt_circle_fill
          : CupertinoIcons.circle,
      iconColor: _isCompleted ? IosTheme.systemGreen : IosTheme.primaryBlue,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _openFullscreen() async {
    final vp = _videoPlayerController;
    if (vp == null || !vp.value.isInitialized) return;

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullscreenVideoPlayer(
          controller: vp,
          title: _currentVideo.title,
          playbackSpeed: _playbackSpeed,
          onSelectSpeed: (s) async {
            setState(() => _playbackSpeed = s);
            await vp.setPlaybackSpeed(s);
          },
        ),
      ),
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mins:$secs';
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _saveCurrentProgress(force: true);
    _hideControlsTimer?.cancel();
    _progressSyncTimer?.cancel();
    _upNextTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _youtubeController?.dispose();
    final vp = _videoPlayerController;
    _videoPlayerController = null;
    vp?.removeListener(_onVideoTick);
    vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoType == 'youtube' && _youtubeController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: IosTheme.primaryBlue,
        ),
        builder: (context, player) => _buildScaffold(youtubeWidget: player),
      );
    }

    return _buildScaffold();
  }

  Widget _buildScaffold({Widget? youtubeWidget}) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(
        title: _currentVideo.title,
        subtitle: widget.courseTitle ?? _currentVideo.displayDuration,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          onPressed: _showSpeedPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: IosTheme.groupedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_playbackSpeed == _playbackSpeed.toInt() ? _playbackSpeed.toInt() : _playbackSpeed}x',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: IosTheme.primaryBlue,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Sticky 16:9 Video Player Surface (Stays fixed at top while scrolling lectures!)
                    _buildPlayerContainer(youtubeWidget: youtubeWidget),

                    // Thin live progress bar right below the video frame
                    LinearProgressIndicator(
                      value: (_watchProgress.clamp(0, 100)) / 100.0,
                      backgroundColor: const Color(0xFFE5E5EA),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isCompleted
                            ? IosTheme.systemGreen
                            : IosTheme.primaryBlue,
                      ),
                      minHeight: 3,
                    ),

                    // Scrollable Lecture Details + Playlist
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLectureInfoCard(),
                            const SizedBox(height: 12),
                            _buildActionRow(),
                            if (_currentVideo.description != null &&
                                _currentVideo.description!.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _buildDescriptionCard(),
                            ],
                            if (_playlist.length > 1) ...[
                              const SizedBox(height: 20),
                              _buildPlaylistSection(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPlayerContainer({Widget? youtubeWidget}) {
    final vp = _videoPlayerController;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: youtubeWidget ??
            (vp != null && vp.value.isInitialized
                ? _buildCustomVideoSurface(vp)
                : const Center(
                    child: CupertinoActivityIndicator(color: Colors.white),
                  )),
      ),
    );
  }

  Widget _buildCustomVideoSurface(VideoPlayerController vp) {
    final value = vp.value;
    final total = value.duration;
    final pos = value.position;
    final totalMs = total.inMilliseconds > 0 ? total.inMilliseconds : 1;
    final progressRatio = _isDraggingSlider
        ? _dragSliderValue.clamp(0.0, 1.0)
        : (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);

    double bufferedRatio = 0.0;
    if (value.buffered.isNotEmpty) {
      bufferedRatio =
          (value.buffered.last.end.inMilliseconds / totalMs).clamp(0.0, 1.0);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
            child: VideoPlayer(vp),
          ),
        ),

        // Double-tap left (-10s) and right (+10s) zones + tap center to toggle controls
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                onDoubleTap: () => _seekBy(-10),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                onDoubleTap: () => _seekBy(10),
              ),
            ),
          ],
        ),

        if (value.isBuffering)
          const Center(
            child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
          ),

        // Seek feedback badge (-10s / +10s)
        if (_seekFeedback != null)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _seekFeedback!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        // Interactive Controls Overlay
        if (_showControls)
          Container(
            color: Colors.black.withValues(alpha: 0.44),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Overlay Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentVideo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showSpeedPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_playbackSpeed == _playbackSpeed.toInt() ? _playbackSpeed.toInt() : _playbackSpeed}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Transport Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_prevUnlockedVideo != null)
                      IconButton(
                        icon: const Icon(
                          CupertinoIcons.backward_end_fill,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => _switchToVideo(_prevUnlockedVideo!),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.gobackward_10,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => _seekBy(-10),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: IosTheme.primaryBlue.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          value.isPlaying
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.goforward_10,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => _seekBy(10),
                    ),
                    const SizedBox(width: 6),
                    if (_nextUnlockedVideo != null)
                      IconButton(
                        icon: const Icon(
                          CupertinoIcons.forward_end_fill,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => _switchToVideo(_nextUnlockedVideo!),
                      ),
                  ],
                ),

                // Bottom Scrubber & Timestamps
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 22,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Buffered track
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: bufferedRatio,
                                  minHeight: 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.25),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: IosTheme.primaryBlue,
                                inactiveTrackColor: Colors.transparent,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 13,
                                ),
                              ),
                              child: Slider(
                                value: progressRatio,
                                onChangeStart: (v) {
                                  _hideControlsTimer?.cancel();
                                  setState(() {
                                    _isDraggingSlider = true;
                                    _dragSliderValue = v;
                                  });
                                },
                                onChanged: (v) {
                                  setState(() => _dragSliderValue = v);
                                },
                                onChangeEnd: (v) async {
                                  final seekMs = (v * totalMs).round();
                                  await vp.seekTo(
                                    Duration(milliseconds: seekMs),
                                  );
                                  setState(() => _isDraggingSlider = false);
                                  _resetHideControlsTimer();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${_formatDuration(_isDraggingSlider ? Duration(milliseconds: (_dragSliderValue * totalMs).round()) : pos)} / ${_formatDuration(total)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _openFullscreen,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                CupertinoIcons.fullscreen,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Up Next Countdown Overlay when video ends
        if (_upNextCountdown > 0 && _nextUnlockedVideo != null)
          Container(
            color: Colors.black.withValues(alpha: 0.8),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'UP NEXT IN ${_upNextCountdown}S',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _nextUnlockedVideo!.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                      onPressed: _cancelUpNext,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      color: IosTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(18),
                      onPressed: () {
                        final next = _nextUnlockedVideo;
                        _cancelUpNext();
                        if (next != null) _switchToVideo(next);
                      },
                      child: const Text(
                        'Play Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLectureInfoCard() {
    final durationLabel = _currentVideo.displayDuration;
    final progressLabel = _isCompleted
        ? 'Completed'
        : (_watchProgress > 0 ? '$_watchProgress% watched' : 'Not started');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_currentIndex >= 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: IosTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'LECTURE ${_currentIndex + 1} OF ${_playlist.length}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: IosTheme.primaryBlue,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_isCompleted
                          ? IosTheme.systemGreen
                          : IosTheme.primaryBlue)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCompleted
                          ? CupertinoIcons.checkmark_alt_circle_fill
                          : CupertinoIcons.chart_bar_fill,
                      size: 12,
                      color: _isCompleted
                          ? IosTheme.systemGreen
                          : IosTheme.primaryBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isCompleted
                            ? IosTheme.systemGreen
                            : IosTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currentVideo.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: IosTheme.labelPrimary,
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (durationLabel != null)
                _buildBadge(
                  CupertinoIcons.time,
                  durationLabel,
                  IosTheme.primaryBlue,
                ),
              if (_currentVideo.isFree == true ||
                  _currentVideo.isPreview == true)
                _buildBadge(
                  CupertinoIcons.sparkles,
                  'Free Preview',
                  IosTheme.systemGreen,
                ),
              if (_currentVideo.viewLimit != null)
                _buildBadge(
                  CupertinoIcons.eye,
                  'Limit: ${_currentVideo.viewLimit} views',
                  IosTheme.systemOrange,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lecture Watch Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: IosTheme.labelTertiary,
                ),
              ),
              Text(
                '$_watchProgress%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isCompleted
                      ? IosTheme.systemGreen
                      : IosTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_watchProgress.clamp(0, 100)) / 100.0,
              backgroundColor: IosTheme.groupedBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isCompleted ? IosTheme.systemGreen : IosTheme.primaryBlue,
              ),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    final prev = _prevUnlockedVideo;
    final next = _nextUnlockedVideo;

    return Row(
      children: [
        Expanded(
          child: _buildActionChip(
            icon: CupertinoIcons.checkmark_alt_circle_fill,
            label: _isCompleted ? 'Completed' : 'Mark Done',
            color: _isCompleted ? IosTheme.systemGreen : IosTheme.primaryBlue,
            filled: _isCompleted,
            onTap: _toggleCompletedManually,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionChip(
            icon: CupertinoIcons.speedometer,
            label:
                'Speed ${_playbackSpeed == _playbackSpeed.toInt() ? _playbackSpeed.toInt() : _playbackSpeed}x',
            color: IosTheme.systemIndigo,
            onTap: _showSpeedPicker,
          ),
        ),
        if (prev != null) ...[
          const SizedBox(width: 8),
          _buildIconOnlyChip(
            icon: CupertinoIcons.backward_end_fill,
            onTap: () => _switchToVideo(prev),
          ),
        ],
        if (next != null) ...[
          const SizedBox(width: 8),
          _buildIconOnlyChip(
            icon: CupertinoIcons.forward_end_fill,
            onTap: () => _switchToVideo(next),
          ),
        ],
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    bool filled = false,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 42),
      onPressed: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? color : IosTheme.separator,
            width: 0.7,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : IosTheme.labelPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconOnlyChip({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(42, 42),
      onPressed: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IosTheme.separator, width: 0.7),
        ),
        child: Icon(icon, size: 17, color: IosTheme.primaryBlue),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ABOUT THIS LECTURE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: IosTheme.labelTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentVideo.description!,
            style: const TextStyle(
              fontSize: 14,
              color: IosTheme.labelSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IosSectionLabel('Course Playlist (${_playlist.length})'),
        IosGroupedCard(
          children: List.generate(_playlist.length, (index) {
            final v = _playlist[index];
            final isPlaying = v.id == _currentVideo.id;
            final isLast = index == _playlist.length - 1;
            final canPlay = _canPlayVideo(v);
            final local = _localProgressMap[v.id];
            final prog = isPlaying
                ? _watchProgress
                : ((local?['progress'] is int &&
                        (local!['progress'] as int) > v.watchProgress)
                    ? local['progress'] as int
                    : v.watchProgress);
            final completed = isPlaying
                ? _isCompleted
                : (v.isWatched || local?['completed'] == true || prog >= 90);

            return Column(
              children: [
                Material(
                  color: isPlaying
                      ? IosTheme.primaryBlue.withValues(alpha: 0.06)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => _switchToVideo(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? IosTheme.primaryBlue
                                  : (completed
                                      ? IosTheme.systemGreen
                                          .withValues(alpha: 0.14)
                                      : (canPlay
                                          ? IosTheme.groupedBg
                                          : IosTheme.groupedBg)),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Icon(
                                isPlaying
                                    ? CupertinoIcons.waveform
                                    : (completed
                                        ? CupertinoIcons.checkmark_alt
                                        : (canPlay
                                            ? CupertinoIcons.play_fill
                                            : CupertinoIcons.lock_fill)),
                                size: 16,
                                color: isPlaying
                                    ? Colors.white
                                    : (completed
                                        ? IosTheme.systemGreen
                                        : (canPlay
                                            ? IosTheme.primaryBlue
                                            : IosTheme.labelTertiary)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isPlaying
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isPlaying
                                        ? IosTheme.primaryBlue
                                        : IosTheme.labelPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (v.displayDuration != null)
                                      Text(
                                        v.displayDuration!,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: IosTheme.labelTertiary,
                                        ),
                                      ),
                                    if (prog > 0) ...[
                                      if (v.displayDuration != null)
                                        const Text(
                                          ' • ',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: IosTheme.labelTertiary,
                                          ),
                                        ),
                                      Text(
                                        completed ? 'Completed' : '$prog%',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: completed
                                              ? IosTheme.systemGreen
                                              : IosTheme.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (prog > 0 && !completed) ...[
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: (prog.clamp(0, 100)) / 100.0,
                                      minHeight: 3,
                                      backgroundColor: IosTheme.groupedBg,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        IosTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isPlaying)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    IosTheme.primaryBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Playing',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.primaryBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(
                    height: 0.5,
                    indent: 60,
                    color: IosTheme.separator,
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _requiresPurchase
                  ? CupertinoIcons.lock_circle_fill
                  : CupertinoIcons.exclamationmark_triangle_fill,
              size: 52,
              color: _requiresPurchase
                  ? IosTheme.systemOrange
                  : IosTheme.systemRed,
            ),
            const SizedBox(height: 14),
            Text(
              _requiresPurchase
                  ? 'Course Enrollment Required'
                  : (_requiresLogin ? 'Sign In Required' : 'Playback Error'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: IosTheme.labelPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: IosTheme.labelTertiary,
              ),
            ),
            const SizedBox(height: 20),
            if (_requiresLogin)
              SizedBox(
                width: 180,
                child: IosPrimaryButton(
                  label: 'Sign In',
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                    if (ok == true) _loadVideoStream();
                  },
                ),
              )
            else if (_requiresPurchase)
              SizedBox(
                width: 180,
                child: IosPrimaryButton(
                  label: 'Back to Course',
                  onPressed: () => Navigator.pop(context),
                ),
              )
            else
              SizedBox(
                width: 160,
                child: IosPrimaryButton(
                  label: 'Retry',
                  onPressed: _loadVideoStream,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final double playbackSpeed;
  final ValueChanged<double> onSelectSpeed;

  const _FullscreenVideoPlayer({
    required this.controller,
    required this.title,
    required this.playbackSpeed,
    required this.onSelectSpeed,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _showControls = true;
  bool _isDragging = false;
  double _dragVal = 0.0;
  late double _speed;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _speed = widget.playbackSpeed;
    widget.controller.addListener(_tick);
    _resetTimer();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    if (widget.controller.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls && !_isDragging) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_tick);
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final val = widget.controller.value;
    final total = val.duration;
    final pos = val.position;
    final totalMs = total.inMilliseconds > 0 ? total.inMilliseconds : 1;
    final ratio =
        _isDragging ? _dragVal : (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _resetTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: val.aspectRatio > 0 ? val.aspectRatio : 16 / 9,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_showControls)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                CupertinoIcons.chevron_down,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              onPressed: () {
                                const list = [0.75, 1.0, 1.25, 1.5, 2.0];
                                final idx = list.indexWhere(
                                  (e) => (e - _speed).abs() < 0.01,
                                );
                                final next = list[(idx + 1) % list.length];
                                setState(() => _speed = next);
                                widget.onSelectSpeed(next);
                              },
                              child: Text(
                                '${_speed == _speed.toInt() ? _speed.toInt() : _speed}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.gobackward_10,
                              color: Colors.white,
                              size: 34,
                            ),
                            onPressed: () async {
                              var t = pos - const Duration(seconds: 10);
                              if (t < Duration.zero) t = Duration.zero;
                              await widget.controller.seekTo(t);
                              _resetTimer();
                            },
                          ),
                          const SizedBox(width: 28),
                          GestureDetector(
                            onTap: () async {
                              if (val.isPlaying) {
                                await widget.controller.pause();
                              } else {
                                await widget.controller.play();
                                _resetTimer();
                              }
                              setState(() {});
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: IosTheme.primaryBlue
                                    .withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                val.isPlaying
                                    ? CupertinoIcons.pause_fill
                                    : CupertinoIcons.play_fill,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.goforward_10,
                              color: Colors.white,
                              size: 34,
                            ),
                            onPressed: () async {
                              var t = pos + const Duration(seconds: 10);
                              if (t > total) t = total;
                              await widget.controller.seekTo(t);
                              _resetTimer();
                            },
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Text(
                              '${_fmt(pos)} / ${_fmt(total)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.5,
                                  activeTrackColor: IosTheme.primaryBlue,
                                  inactiveTrackColor:
                                      Colors.white.withValues(alpha: 0.3),
                                  thumbColor: Colors.white,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7,
                                  ),
                                ),
                                child: Slider(
                                  value: ratio,
                                  onChangeStart: (v) {
                                    _hideTimer?.cancel();
                                    setState(() {
                                      _isDragging = true;
                                      _dragVal = v;
                                    });
                                  },
                                  onChanged: (v) =>
                                      setState(() => _dragVal = v),
                                  onChangeEnd: (v) async {
                                    await widget.controller.seekTo(
                                      Duration(
                                        milliseconds: (v * totalMs).round(),
                                      ),
                                    );
                                    setState(() => _isDragging = false);
                                    _resetTimer();
                                  },
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                CupertinoIcons.fullscreen_exit,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

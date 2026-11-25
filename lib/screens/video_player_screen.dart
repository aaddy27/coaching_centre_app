import 'package:chewie/chewie.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video.dart';
import '../registration/login_screen.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  bool _requiresPurchase = false;
  bool _requiresLogin = false;
  String? _errorMessage;

  String? _videoUrl;
  String _videoType = 'upload';
  String? _displayDuration;

  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _displayDuration = widget.video.displayDuration;
    _loadVideoStream();
  }

  Future<void> _loadVideoStream() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _requiresPurchase = false;
      _requiresLogin = false;
    });

    try {
      final loggedIn = await ApiService.isLoggedIn();

      if (loggedIn) {
        final response = await ApiService.streamVideo(widget.video.id);
        if (!mounted) return;

        if (response['success'] == true && response['data'] != null) {
          final videoMap = response['data']['video'] as Map<String, dynamic>? ??
              response['data'] as Map<String, dynamic>;
          _videoUrl = videoMap['video_url']?.toString() ?? widget.video.videoUrl;
          _videoType =
              videoMap['video_type']?.toString() ?? widget.video.videoType;
        } else {
          final statusCode = response['status_code'];
          final reqPurchase = response['data']?['requires_purchase'] == true ||
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
      } else if (widget.video.videoUrl != null &&
          widget.video.videoUrl!.isNotEmpty &&
          (widget.video.isPreview == true || widget.video.isFree == true)) {
        _videoUrl = widget.video.videoUrl;
        _videoType = widget.video.videoType;
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
      setState(() {
        _errorMessage = 'Error loading video: ${e.toString()}';
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

    // Detect YouTube URLs
    if (_videoType == 'youtube' ||
        url.contains('youtube.com') ||
        url.contains('youtu.be')) {
      final ytId = YoutubePlayer.convertUrlToId(url) ?? widget.video.youtubeId;
      if (ytId != null && ytId.isNotEmpty) {
        _videoType = 'youtube';
        _youtubeController = YoutubePlayerController(
          initialVideoId: ytId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            enableCaption: true,
          ),
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    // Standard MP4 / HLS stream via video_player + chewie
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: IosTheme.primaryBlue,
        handleColor: IosTheme.primaryBlue,
        bufferedColor: IosTheme.primaryBlue.withValues(alpha: 0.3),
        backgroundColor: Colors.white24,
      ),
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: IosTheme.primaryBlue,
        handleColor: IosTheme.primaryBlue,
      ),
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
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
        title: widget.video.title,
        subtitle: _displayDuration,
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Player Area
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: Colors.black,
                          child: youtubeWidget ??
                              (_chewieController != null
                                  ? Chewie(controller: _chewieController!)
                                  : const Center(
                                      child: CupertinoActivityIndicator(
                                        color: Colors.white,
                                      ),
                                    )),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: IosTheme.separator,
                                  width: 0.6,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.video.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: IosTheme.labelPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (_displayDuration != null)
                                        _buildBadge(
                                          CupertinoIcons.time,
                                          _displayDuration!,
                                          IosTheme.primaryBlue,
                                        ),
                                      if (widget.video.isFree == true ||
                                          widget.video.isPreview == true)
                                        _buildBadge(
                                          CupertinoIcons.sparkles,
                                          'Free Preview',
                                          IosTheme.systemGreen,
                                        ),
                                      if (widget.video.viewLimit != null)
                                        _buildBadge(
                                          CupertinoIcons.eye,
                                          'Limit: ${widget.video.viewLimit} views',
                                          IosTheme.systemOrange,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (widget.video.description != null &&
                                widget.video.description!.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: IosTheme.separator,
                                    width: 0.6,
                                  ),
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
                                      widget.video.description!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: IosTheme.labelSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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

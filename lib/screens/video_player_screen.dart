import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video.dart';
import '../services/api_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({
    Key? key,
    required this.video,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _videoData;
  YoutubePlayerController? _youtubeController;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _loadVideoStream();
  }

  Future<void> _loadVideoStream() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if video URL is already available from the video object
      if (widget.video.videoUrl != null && widget.video.videoUrl!.isNotEmpty) {
        print('✅ Video URL already available: ${widget.video.videoUrl}');
        print('📹 Video Type: ${widget.video.videoType}');
        
        // Create video data from existing video object
        _videoData = {
          'video': {
            'id': widget.video.id,
            'title': widget.video.title,
            'description': widget.video.description,
            'video_type': widget.video.videoType,
            'video_url': widget.video.videoUrl,
            'vimeo_id': widget.video.vimeoId,
            'youtube_id': widget.video.youtubeId,
            'duration_seconds': widget.video.durationSeconds,
            'thumbnail': widget.video.thumbnail,
            'is_preview': widget.video.isPreview,
            'status': widget.video.status,
          }
        };
        
        // Initialize player based on video type
        _initializePlayer();
        
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // If video URL not available, fetch from stream API
      print('🔄 Fetching video data from stream API...');
      final response = await ApiService.streamVideo(widget.video.id);

      if (response['success'] == true) {
        setState(() {
          _videoData = response['data'];
          _isLoading = false;
        });
        _initializePlayer();
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load video';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _initializePlayer() {
    final videoInfo = _videoData?['video'];
    final videoType = videoInfo?['video_type'] ?? widget.video.videoType;
    final videoUrl = videoInfo?['video_url'] ?? widget.video.videoUrl;

    print('🎬 Initializing player...');
    print('   Video Type: $videoType');
    print('   Video URL: $videoUrl');

    if (videoType == 'youtube' && videoUrl != null) {
      // Extract YouTube video ID
      final videoId = YoutubePlayer.convertUrlToId(videoUrl);
      
      print('   Extracted YouTube ID: $videoId');
      
      if (videoId != null) {
        print('✅ Creating YouTube controller with ID: $videoId');
        
        setState(() {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              enableCaption: true,
              controlsVisibleAtStart: true,
              hideControls: false,
            ),
          );

          _youtubeController!.addListener(() {
            if (_youtubeController!.value.isReady && !_isPlayerReady) {
              setState(() {
                _isPlayerReady = true;
                print('✅ YouTube player is ready!');
              });
            }
          });
        });
      } else {
        print('❌ Failed to extract YouTube ID from URL');
        setState(() {
          _errorMessage = 'Invalid YouTube URL: $videoUrl';
        });
      }
    } else {
      print('⚠️  Video type is not YouTube or URL is null');
      print('   Type: $videoType, URL: $videoUrl');
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController ?? 
          YoutubePlayerController(
            initialVideoId: 'dQw4w9WgXcQ', // Dummy ID
            flags: const YoutubePlayerFlags(autoPlay: false),
          ),
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF6366F1),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF6366F1),
          handleColor: Color(0xFF6366F1),
        ),
        onReady: () {
          print('✅ YouTube player ready');
        },
        onEnded: (data) {
          print('✅ Video ended');
        },
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          appBar: _buildModernAppBar(),
          body: _buildBody(player),
        );
      },
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargePhone = screenWidth > 400;
    
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: isTablet ? 80 : (isLargePhone ? 70 : 65),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
        iconSize: isTablet ? 26 : 24,
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.play_circle_rounded,
              color: Colors.white,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: isTablet ? 14 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.video.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 18 : (isLargePhone ? 16 : 14),
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isLargePhone && widget.video.duration != null)
                  Text(
                    widget.video.duration!,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Widget player) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _loadVideoStream,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Player
          _buildVideoPlayer(player),

          // Video Info (directly without tabs)
          _buildInfoTab(),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(Widget player) {
    final videoInfo = _videoData?['video'];
    final videoType = videoInfo?['video_type'] ?? widget.video.videoType;

    // If YouTube video and player is initialized, show it
    if (videoType == 'youtube' && _youtubeController != null) {
      return player;
    }

    // Otherwise show placeholder
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail
            if (widget.video.thumbnail != null)
              Image.network(
                widget.video.thumbnail!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 80,
                      color: Colors.white54,
                    ),
                  );
                },
              ),

            // Overlay
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      videoType == 'vimeo'
                          ? 'Loading Vimeo Player...'
                          : videoType == 'youtube'
                              ? 'Loading YouTube Player...'
                              : 'Loading Video Player...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Stats Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Row
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (widget.video.duration != null)
                      _buildStatChip(
                        icon: Icons.access_time_rounded,
                        label: widget.video.duration!,
                        color: const Color(0xFF6366F1),
                      ),
                    if (widget.video.views != null)
                      _buildStatChip(
                        icon: Icons.visibility_rounded,
                        label: '${widget.video.views} views',
                        color: const Color(0xFF10B981),
                      ),
                    _buildStatChip(
                      icon: Icons.video_library_rounded,
                      label: widget.video.videoType.toUpperCase(),
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),

                // Progress Bar
                if (widget.video.watchProgress > 0) ...[
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your Progress',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.video.watchProgress}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: widget.video.watchProgress / 100,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6366F1),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Description Card
          if (widget.video.description != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.video.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedTab() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.playlist_play_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Related Videos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Related videos will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

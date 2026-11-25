import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../models/video.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';
import 'video_player_screen.dart';

class SubjectVideosScreen extends StatefulWidget {
  final int courseId;
  final Subject subject;
  final bool isEnrolled;
  final double coursePrice;

  const SubjectVideosScreen({
    super.key,
    required this.courseId,
    required this.subject,
    required this.isEnrolled,
    required this.coursePrice,
  });

  @override
  State<SubjectVideosScreen> createState() => _SubjectVideosScreenState();
}

class _SubjectVideosScreenState extends State<SubjectVideosScreen> {
  List<Video> _videos = [];
  bool _isLoading = true;
  bool _hasPurchased = false;
  String? _errorMessage;
  String? _selectedFilter;
  String? _selectedSort;

  @override
  void initState() {
    super.initState();
    _hasPurchased = widget.isEnrolled || widget.coursePrice <= 0;
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getSubjectVideos(
        courseId: widget.courseId,
        subjectId: widget.subject.id,
        filter: _selectedFilter,
        sort: _selectedSort,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final List<dynamic> videosData = data['videos'] ?? [];
        setState(() {
          _hasPurchased = (data['has_purchased'] == true) ||
              widget.isEnrolled ||
              widget.coursePrice <= 0;
          _videos = videosData.map((json) => Video.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = ApiService.extractErrorMessage(
            response,
            fallback: 'Failed to load videos.',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showFilterOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: const Text('Filter & Sort Lectures'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetCtx);
              setState(() => _selectedFilter = null);
              _loadVideos();
            },
            child: Text(
              _selectedFilter == null ? '✓ All Videos' : 'All Videos',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetCtx);
              setState(() => _selectedFilter = 'unwatched');
              _loadVideos();
            },
            child: Text(
              _selectedFilter == 'unwatched' ? '✓ Unwatched' : 'Unwatched',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetCtx);
              setState(() => _selectedFilter = 'watched');
              _loadVideos();
            },
            child: Text(
              _selectedFilter == 'watched' ? '✓ Watched' : 'Watched',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetCtx);
              setState(() => _selectedSort = 'duration');
              _loadVideos();
            },
            child: Text(
              _selectedSort == 'duration'
                  ? '✓ Shortest First'
                  : 'Sort: Shortest First',
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetCtx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showLockedDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Lecture Locked'),
        content: const Text(
          'Purchase this course from the Course Details page to unlock all video lectures.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context); // Return to CourseDetailScreen to enroll
            },
            child: const Text('Go to Enroll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(
        title: widget.subject.name,
        subtitle: '${_videos.length} Videos',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          onPressed: _showFilterOptions,
          child: const Icon(
            CupertinoIcons.line_horizontal_3_decrease_circle,
            color: IosTheme.primaryBlue,
            size: 22,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _errorMessage != null
              ? _buildError()
              : _videos.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadVideos,
                      color: IosTheme.primaryBlue,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          final canPlay = _hasPurchased ||
                              video.canPlay ||
                              video.isPreview == true ||
                              video.isFree == true;

                          return _buildVideoCard(video, index, canPlay);
                        },
                      ),
                    ),
    );
  }

  Widget _buildVideoCard(Video video, int index, bool canPlay) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!canPlay) {
              _showLockedDialog();
              return;
            }
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => VideoPlayerScreen(video: video),
              ),
            ).then((_) => _loadVideos());
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 108,
                        height: 66,
                        color: IosTheme.groupedBg,
                        child: video.thumbnail != null &&
                                video.thumbnail!.isNotEmpty
                            ? Image.network(
                                video.thumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildThumbIcon(canPlay),
                              )
                            : _buildThumbIcon(canPlay),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: canPlay
                            ? IosTheme.primaryBlue.withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        canPlay
                            ? CupertinoIcons.play_fill
                            : CupertinoIcons.lock_fill,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Lecture ${video.order > 0 ? video.order : index + 1}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.primaryBlue,
                            ),
                          ),
                          if (video.isPreview == true ||
                              video.isFree == true) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    IosTheme.systemGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.systemGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: IosTheme.labelPrimary,
                        ),
                      ),
                      if (video.displayDuration != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          video.displayDuration!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: IosTheme.labelTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Color(0xFFC7C7CC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbIcon(bool canPlay) {
    return Container(
      color: IosTheme.groupedBg,
      child: Center(
        child: Icon(
          CupertinoIcons.play_rectangle_fill,
          size: 28,
          color: canPlay
              ? IosTheme.primaryBlue.withValues(alpha: 0.3)
              : IosTheme.labelTertiary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.video_camera,
              size: 48,
              color: IosTheme.labelTertiary,
            ),
            SizedBox(height: 12),
            Text(
              'No Lectures Available',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: IosTheme.labelPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: IosTheme.systemRed,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 150,
              child: IosPrimaryButton(label: 'Retry', onPressed: _loadVideos),
            ),
          ],
        ),
      ),
    );
  }
}

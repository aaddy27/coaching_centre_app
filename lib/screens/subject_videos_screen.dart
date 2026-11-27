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
  List<Video> _allVideos = [];
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
      final results = await Future.wait([
        ApiService.getSubjectVideos(
          courseId: widget.courseId,
          subjectId: widget.subject.id,
          sort: _selectedSort,
        ),
        ApiService.getLocalVideoProgressMap(),
      ]);

      if (!mounted) return;

      final response = results[0] as Map<String, dynamic>;
      final localProgMap = results[1] as Map<int, Map<String, dynamic>>;

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final List<dynamic> videosData = data['videos'] ?? [];

        final merged = videosData.map((json) {
          final parsed = Video.fromJson(json);
          final local = localProgMap[parsed.id];
          if (local == null) return parsed;
          final lp = local['progress'] is int ? local['progress'] as int : 0;
          final ls = local['watched_seconds'] is int
              ? local['watched_seconds'] as int
              : 0;
          final lc = local['completed'] == true;
          return parsed.copyWithProgress(
            watchProgress:
                lp > parsed.watchProgress ? lp : parsed.watchProgress,
            watchedSeconds:
                ls > parsed.watchedSeconds ? ls : parsed.watchedSeconds,
            isWatched: parsed.isWatched || lc || lp >= 90,
          );
        }).toList();

        setState(() {
          _hasPurchased = (data['has_purchased'] == true) ||
              widget.isEnrolled ||
              widget.coursePrice <= 0;
          _allVideos = merged;
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

  List<Video> get _filteredVideos {
    if (_selectedFilter == 'watched') {
      return _allVideos
          .where((v) => v.isWatched || v.watchProgress >= 90)
          .toList();
    } else if (_selectedFilter == 'unwatched') {
      return _allVideos
          .where((v) => !v.isWatched && v.watchProgress < 90)
          .toList();
    }
    return _allVideos;
  }

  void _openVideo(Video video) {
    final canPlay = _hasPurchased ||
        video.canPlay ||
        video.isPreview == true ||
        video.isFree == true;

    if (!canPlay) {
      _showLockedDialog();
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => VideoPlayerScreen(
          video: video,
          playlist: _allVideos,
          courseTitle: widget.subject.name,
          courseId: widget.courseId,
          hasPurchased: _hasPurchased,
        ),
      ),
    ).then((_) => _loadVideos());
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
            },
            child: Text(
              _selectedFilter == null ? '✓ All Videos' : 'All Videos',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetCtx);
              setState(() => _selectedFilter = 'unwatched');
            },
            child: Text(
              _selectedFilter == 'unwatched' ? '✓ Unwatched' : 'Unwatched',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetCtx);
              setState(() => _selectedFilter = 'watched');
            },
            child: Text(
              _selectedFilter == 'watched' ? '✓ Watched' : 'Watched',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetCtx);
              setState(() {
                _selectedSort =
                    _selectedSort == 'duration' ? null : 'duration';
              });
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
              Navigator.pop(context);
            },
            child: const Text('Go to Enroll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _filteredVideos;

    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(
        title: widget.subject.name,
        subtitle: '${_allVideos.length} Videos',
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
              : _allVideos.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadVideos,
                      color: IosTheme.primaryBlue,
                      child: ListView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSubjectProgressCard(),
                          if (videos.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'No lectures match the selected filter.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: IosTheme.labelTertiary,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...List.generate(videos.length, (index) {
                              final video = videos[index];
                              final canPlay = _hasPurchased ||
                                  video.canPlay ||
                                  video.isPreview == true ||
                                  video.isFree == true;
                              return _buildVideoCard(video, index, canPlay);
                            }),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSubjectProgressCard() {
    final total = _allVideos.length;
    final completed = _allVideos
        .where((v) => v.isWatched || v.watchProgress >= 90)
        .length;
    final sumProgress = _allVideos.fold<int>(
      0,
      (acc, v) => acc + (v.isWatched ? 100 : v.watchProgress.clamp(0, 100)),
    );
    final pct = total > 0 ? (sumProgress / total).round().clamp(0, 100) : 0;
    final isAllDone = total > 0 && completed == total;

    final nextCandidates = _allVideos.where((v) {
      final canPlay = _hasPurchased ||
          v.canPlay ||
          v.isPreview == true ||
          v.isFree == true;
      return canPlay && !v.isWatched && v.watchProgress < 90;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              const Text(
                'SUBJECT PROGRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: IosTheme.labelTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAllDone
                          ? IosTheme.systemGreen
                          : IosTheme.primaryBlue)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isAllDone
                        ? IosTheme.systemGreen
                        : IosTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 7,
              backgroundColor: IosTheme.groupedBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                isAllDone ? IosTheme.systemGreen : IosTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completed of $total lectures completed',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: IosTheme.labelTertiary,
                  ),
                ),
              ),
              if (nextCandidates.isNotEmpty)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  minimumSize: const Size(44, 30),
                  color: IosTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () => _openVideo(nextCandidates.first),
                  child: Text(
                    nextCandidates.first.watchProgress > 0
                        ? 'Resume'
                        : 'Start Next',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Video video, int index, bool canPlay) {
    final isCompleted = video.isWatched || video.watchProgress >= 90;
    final prog = isCompleted ? 100 : video.watchProgress.clamp(0, 100);

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
          onTap: () => _openVideo(video),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 112,
                        height: 68,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
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
                            if (prog > 0)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: LinearProgressIndicator(
                                  value: prog / 100.0,
                                  minHeight: 3.5,
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isCompleted
                                        ? IosTheme.systemGreen
                                        : IosTheme.primaryBlue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? IosTheme.systemGreen.withValues(alpha: 0.92)
                            : (canPlay
                                ? IosTheme.primaryBlue.withValues(alpha: 0.9)
                                : Colors.black.withValues(alpha: 0.65)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted
                            ? CupertinoIcons.checkmark_alt
                            : (canPlay
                                ? CupertinoIcons.play_fill
                                : CupertinoIcons.lock_fill),
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Lecture ${video.order > 0 ? video.order : index + 1}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.primaryBlue,
                            ),
                          ),
                          if (video.isPreview == true || video.isFree == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: IosTheme.systemGreen
                                    .withValues(alpha: 0.12),
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
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: IosTheme.systemGreen
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.systemGreen,
                                ),
                              ),
                            )
                          else if (prog > 0)
                            Text(
                              '$prog%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: IosTheme.primaryBlue,
                              ),
                            ),
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

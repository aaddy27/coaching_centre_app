import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedSegment = 0; // 0: All, 1: Free, 2: Paid
  int? _selectedExamBoardId;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getAllCourses();
      if (!mounted) return;

      if (response['success'] == true ||
          response['success'] == 1 ||
          response['success'] == '1') {
        List<dynamic> coursesData = [];
        if (response['data'] != null) {
          if (response['data'] is List) {
            coursesData = response['data'];
          } else if (response['data']['courses'] is List) {
            coursesData = response['data']['courses'];
          }
        } else if (response['courses'] is List) {
          coursesData = response['courses'];
        }

        setState(() {
          _courses = coursesData.map((json) => Course.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = ApiService.extractErrorMessage(
            response,
            fallback: 'Failed to load courses',
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server.';
        _isLoading = false;
      });
    }
  }

  List<ExamBoard> get _availableExamBoards {
    final seen = <int, ExamBoard>{};
    for (final c in _courses) {
      if (c.examBoard != null && c.examBoard!.id > 0) {
        seen.putIfAbsent(c.examBoard!.id, () => c.examBoard!);
      }
    }
    return seen.values.toList();
  }

  List<Course> get _filteredCourses {
    return _courses.where((course) {
      if (_selectedSegment == 1 && course.price > 0) return false;
      if (_selectedSegment == 2 && course.price <= 0) return false;

      if (_selectedExamBoardId != null &&
          course.examBoard?.id != _selectedExamBoardId &&
          course.examBoardId != _selectedExamBoardId) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final titleMatch = course.title.toLowerCase().contains(query);
        final descMatch = course.description.toLowerCase().contains(query);
        final boardMatch =
            course.examBoard?.name.toLowerCase().contains(query) ?? false;
        final subjectMatch = course.subjects?.any(
              (s) => s.name.toLowerCase().contains(query),
            ) ??
            false;
        if (!titleMatch && !descMatch && !boardMatch && !subjectMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  int get _allCount => _courses.length;
  int get _freeCount => _courses.where((c) => c.price <= 0).length;
  int get _paidCount => _courses.where((c) => c.price > 0).length;

  void _showShareSheet(Course course) {
    final shareUrl = 'https://eduapp.hkrdn.in/course/${course.slug}';
    final priceText =
        course.price <= 0 ? 'FREE' : '₹${course.price.toStringAsFixed(0)}';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext sheetContext) => CupertinoActionSheet(
        title: Text(
          course.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: IosTheme.labelPrimary,
          ),
        ),
        message: Text(
          'Price: $priceText • ${course.totalVideos ?? 0} Videos\nShare this course with friends & study groups',
          style: const TextStyle(fontSize: 13, color: IosTheme.labelTertiary),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: shareUrl));
              showIosToast(
                context,
                title: 'Link Copied',
                message: 'Course link copied to clipboard.',
                icon: CupertinoIcons.link,
                iconColor: IosTheme.primaryBlue,
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.link, color: IosTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Copy Course Link',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: IosTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              final waText = '📚 *${course.title}*\n'
                  '🎯 Complete Online Course with HD Video Lectures & Notes.\n'
                  '💰 Price: $priceText\n'
                  '📹 Total Videos: ${course.totalVideos ?? "Complete Syllabus"}\n'
                  '🔗 Enroll Now: $shareUrl';
              Clipboard.setData(ClipboardData(text: waText));
              showIosToast(
                context,
                title: 'Ready to Share',
                message: 'Course info copied! Paste in WhatsApp or Telegram.',
                icon: CupertinoIcons.chat_bubble_2_fill,
                iconColor: IosTheme.systemGreen,
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  color: IosTheme.systemGreen,
                  size: 20,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Share on WhatsApp / Telegram',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: IosTheme.systemGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: IosTheme.primaryBlue,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boards = _availableExamBoards;

    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildIosHeader(),
            _buildSearchBar(),
            _buildSegmentedTabs(),
            if (boards.isNotEmpty) _buildExamBoardChips(boards),
            const Divider(height: 1, thickness: 0.5, color: IosTheme.separator),
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosHeader() {
    final canPop = Navigator.canPop(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: canPop ? 6 : 14,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(32, 32),
                onPressed: () => Navigator.maybePop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.chevron_left,
                      color: IosTheme.primaryBlue,
                      size: 22,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: IosTheme.primaryBlue,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore Courses',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: IosTheme.labelPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Video lectures & structured exam syllabus',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: IosTheme.labelTertiary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: _loadCourses,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IosTheme.groupedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_clockwise,
                    size: 18,
                    color: IosTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search courses, subjects, exam boards...',
        backgroundColor: IosTheme.groupedBg,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        style: const TextStyle(fontSize: 15, color: IosTheme.labelPrimary),
        placeholderStyle:
            const TextStyle(fontSize: 15, color: IosTheme.labelTertiary),
        onChanged: (value) => setState(() => _searchQuery = value),
        onSuffixTap: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedSegment,
          backgroundColor: const Color(0xFFEFEFF4),
          thumbColor: Colors.white,
          padding: const EdgeInsets.all(3),
          children: {
            0: _buildSegmentItem('All', _allCount, 0),
            1: _buildSegmentItem('Free', _freeCount, 1),
            2: _buildSegmentItem('Paid', _paidCount, 2),
          },
          onValueChanged: (val) {
            if (val != null) setState(() => _selectedSegment = val);
          },
        ),
      ),
    );
  }

  Widget _buildExamBoardChips(List<ExamBoard> boards) {
    return Container(
      color: Colors.white,
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          _buildFilterChip(
            label: 'All Exams',
            selected: _selectedExamBoardId == null,
            onTap: () => setState(() => _selectedExamBoardId = null),
          ),
          ...boards.map(
            (board) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildFilterChip(
                label: board.name,
                selected: _selectedExamBoardId == board.id,
                onTap: () => setState(() {
                  _selectedExamBoardId =
                      _selectedExamBoardId == board.id ? null : board.id;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? IosTheme.primaryBlue : IosTheme.groupedBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : IosTheme.labelPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentItem(String title, int count, int index) {
    final isSelected = _selectedSegment == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? IosTheme.labelPrimary
                    : IosTheme.labelTertiary,
              ),
            ),
            if (count > 0 || index == 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? IosTheme.primaryBlue
                      : const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final list = _filteredCourses;
    if (list.isEmpty) return _buildEmptyState();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _loadCourses),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCourseCard(list[index]),
              childCount: list.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(Course course) {
    final bool isFree = course.price <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IosTheme.separator, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => CourseDetailScreen(course: course),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(17)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: course.effectiveThumbnail != null
                          ? Image.network(
                              course.effectiveThumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildThumbnailPlaceholder(course),
                            )
                          : _buildThumbnailPlaceholder(course),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isFree
                            ? IosTheme.systemGreen
                            : IosTheme.labelPrimary.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isFree ? 'FREE' : '₹${course.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (course.examBoard != null &&
                      course.examBoard!.name.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          course.examBoard!.name,
                          style: const TextStyle(
                            color: IosTheme.labelPrimary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.labelPrimary,
                        letterSpacing: -0.3,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (course.description.isNotEmpty)
                      Text(
                        course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: IosTheme.labelTertiary,
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (course.subjects != null &&
                            course.subjects!.isNotEmpty)
                          ...course.subjects!.take(3).map(
                                (s) => _buildMiniBadge(
                                  CupertinoIcons.book,
                                  s.videosCount != null
                                      ? '${s.name} (${s.videosCount})'
                                      : s.name,
                                ),
                              ),
                        if (course.totalVideos != null &&
                            course.totalVideos! > 0)
                          _buildMiniBadge(
                            CupertinoIcons.play_circle_fill,
                            '${course.totalVideos} Videos',
                          ),
                        if (course.duration != null &&
                            course.duration!.isNotEmpty)
                          _buildMiniBadge(
                            CupertinoIcons.time,
                            course.duration!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: IosTheme.separator,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (course.isPurchased)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: IosTheme.systemGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_alt_circle_fill,
                                  color: IosTheme.systemGreen,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Enrolled',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: IosTheme.systemGreen,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            isFree
                                ? 'Free Access'
                                : '₹${course.price.toStringAsFixed(0)} ${course.currency}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.labelPrimary,
                            ),
                          ),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                          onPressed: () => _showShareSheet(course),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: IosTheme.groupedBg,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              CupertinoIcons.share,
                              size: 18,
                              color: IosTheme.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: const Size(36, 36),
                          color: isFree
                              ? IosTheme.systemGreen
                              : IosTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(18),
                          onPressed: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) =>
                                    CourseDetailScreen(course: course),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                course.isPurchased
                                    ? 'Open Course'
                                    : (isFree ? 'Enroll Free' : 'View Course'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                size: 13,
                                color: Colors.white,
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(Course course) {
    return Container(
      color: IosTheme.primaryBlue,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.play_circle_fill,
              size: 46,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                course.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: IosTheme.groupedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: IosTheme.labelTertiary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: IosTheme.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData emptyIcon;
    String emptyTitle;
    String emptySubtitle;
    String buttonText;
    VoidCallback onButtonTap;

    if (_searchQuery.trim().isNotEmpty || _selectedExamBoardId != null) {
      emptyIcon = CupertinoIcons.search;
      emptyTitle = 'No Matches Found';
      emptySubtitle = _searchQuery.trim().isNotEmpty
          ? 'No courses matched "$_searchQuery".'
          : 'No courses available for the selected exam board.';
      buttonText = 'Clear Filters';
      onButtonTap = () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _selectedExamBoardId = null;
          _selectedSegment = 0;
        });
      };
    } else if (_selectedSegment == 1) {
      emptyIcon = CupertinoIcons.gift;
      emptyTitle = 'No Free Courses Currently';
      emptySubtitle =
          'Free courses are added periodically. Check out our full catalog.';
      buttonText = 'Browse All Courses';
      onButtonTap = () => setState(() => _selectedSegment = 0);
    } else {
      emptyIcon = CupertinoIcons.book;
      emptyTitle = 'No Courses Available';
      emptySubtitle = 'There are no active courses at this time.';
      buttonText = 'Refresh';
      onButtonTap = _loadCourses;
    }

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: IosTheme.separator),
              ),
              child: Icon(emptyIcon, size: 38, color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 18),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: IosTheme.labelPrimary,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: IosTheme.labelTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: IosTheme.primaryBlue,
              borderRadius: BorderRadius.circular(20),
              onPressed: onButtonTap,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: IosTheme.systemRed,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could Not Load Courses',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: IosTheme.labelPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Please check your internet connection.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: IosTheme.primaryBlue,
              borderRadius: BorderRadius.circular(20),
              onPressed: _loadCourses,
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

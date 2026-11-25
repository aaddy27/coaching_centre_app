import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/course.dart';
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

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedSegment = 0; // 0: All, 1: Free, 2: Paid

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

      if (response['success'] == true ||
          response['success'] == 1 ||
          response['success'] == '1') {
        List<dynamic> coursesData = [];

        if (response['data'] != null) {
          if (response['data'] is List) {
            coursesData = response['data'];
          } else if (response['data']['courses'] != null) {
            coursesData = response['data']['courses'];
          }
        } else if (response['courses'] != null) {
          coursesData = response['courses'];
        }

        if (mounted) {
          setState(() {
            _courses =
                coursesData.map((json) => Course.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to load courses';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network Error: Unable to connect to server.';
          _isLoading = false;
        });
      }
    }
  }

  // Filtered courses based on segment & search query
  List<Course> get _filteredCourses {
    return _courses.where((course) {
      // 1. Segment Filter
      if (_selectedSegment == 1 && course.price > 0) {
        return false; // Free tab
      } else if (_selectedSegment == 2 && course.price <= 0) {
        return false; // Paid tab
      }

      // 2. Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final titleMatch = course.title.toLowerCase().contains(query);
        final descMatch = course.description.toLowerCase().contains(query);
        final levelMatch =
            course.level?.toLowerCase().contains(query) ?? false;
        if (!titleMatch && !descMatch && !levelMatch) return false;
      }

      return true;
    }).toList();
  }

  int get _allCount => _courses.length;
  int get _freeCount => _courses.where((c) => c.price <= 0).length;
  int get _paidCount => _courses.where((c) => c.price > 0).length;

  // ==================== iOS Share Action Sheet ====================
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
            color: Color(0xFF1C1C1E),
          ),
        ),
        message: Text(
          'Price: $priceText • ${course.totalVideos ?? 0} Videos\nShare this course with friends & study groups',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8E8E93),
          ),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: shareUrl));
              _showIosToast(
                title: 'Link Copied',
                message: 'Course link copied to clipboard.',
                icon: CupertinoIcons.link,
                iconColor: const Color(0xFF007AFF),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.link, color: Color(0xFF007AFF), size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Copy Course Link',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF007AFF),
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
              _showIosToast(
                title: 'Ready to Share',
                message: 'Course info copied! Paste in WhatsApp or Telegram.',
                icon: CupertinoIcons.chat_bubble_2_fill,
                iconColor: const Color(0xFF34C759),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  color: Color(0xFF34C759),
                  size: 20,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Share on WhatsApp / Telegram',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF34C759),
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
              color: Color(0xFF007AFF),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== iOS Toast Notification ====================
  void _showIosToast({
    required String title,
    required String message,
    IconData icon = CupertinoIcons.checkmark_alt_circle_fill,
    Color iconColor = const Color(0xFF34C759),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE5E5EA),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. iOS Large Header with Title & Refresh
            _buildIosHeader(),

            // 2. Native iOS Search Bar
            _buildSearchBar(),

            // 3. Segmented Tabs (All, Free, Paid)
            _buildSegmentedTabs(),

            const Divider(
              height: 1,
              thickness: 0.5,
              color: Color(0xFFE5E5EA),
            ),

            // 4. Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Header Widget ====================
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
                      color: Color(0xFF007AFF),
                      size: 22,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 17,
                        fontWeight: FontWeight.normal,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explore Courses',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'High-yield video lectures & comprehensive syllabus',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
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
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_clockwise,
                    size: 18,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Native Search Bar ====================
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search courses, subjects, topics...',
        backgroundColor: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1C1C1E),
        ),
        placeholderStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFF8E8E93),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        onSuffixTap: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
          });
        },
      ),
    );
  }

  // ==================== Sliding Segmented Control ====================
  Widget _buildSegmentedTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final control = CupertinoSlidingSegmentedControl<int>(
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
              if (val != null) {
                setState(() {
                  _selectedSegment = val;
                });
              }
            },
          );

          return SizedBox(
            width: double.infinity,
            child: control,
          );
        },
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
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFF8E8E93),
              ),
            ),
            if (count > 0 || index == 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF007AFF)
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

  // ==================== Main List View ====================
  Widget _buildListView() {
    final list = _filteredCourses;

    if (list.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _loadCourses,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final course = list[index];
                return _buildCourseCard(course);
              },
              childCount: list.length,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== iOS Native Course Card ====================
  Widget _buildCourseCard(Course course) {
    final bool isFree = course.price <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E5EA),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => CourseDetailScreen(course: course),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Thumbnail Image with Overlay Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: course.effectiveThumbnail != null
                          ? Image.network(
                              course.effectiveThumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildThumbnailPlaceholder(course),
                            )
                          : _buildThumbnailPlaceholder(course),
                    ),
                  ),

                  // Top-Right Price / Free Badge
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
                            ? const Color(0xFF34C759)
                            : const Color(0xFF1C1C1E).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
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

                  // Top-Left Category / Level Badge if available
                  if (course.level != null && course.level!.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          course.level!.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF1C1C1E),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // 2. Course Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.3,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Description
                    if (course.description.isNotEmpty)
                      Text(
                        course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                          height: 1.35,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Metadata Specs (Videos, Duration, Tests)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (course.totalVideos != null &&
                            course.totalVideos! > 0)
                          _buildMiniBadge(
                            CupertinoIcons.play_circle_fill,
                            '${course.totalVideos} Lessons',
                          ),
                        if (course.duration != null &&
                            course.duration!.isNotEmpty)
                          _buildMiniBadge(
                            CupertinoIcons.time,
                            course.duration!,
                          ),
                        if (course.totalTests != null && course.totalTests! > 0)
                          _buildMiniBadge(
                            CupertinoIcons.doc_checkmark_fill,
                            '${course.totalTests} Tests',
                          ),
                        if (course.language != null &&
                            course.language!.isNotEmpty)
                          _buildMiniBadge(
                            CupertinoIcons.globe,
                            course.language!,
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Color(0xFFE5E5EA),
                    ),
                    const SizedBox(height: 10),

                    // Bottom Action Row: Rating, Share & CTA Button
                    Row(
                      children: [
                        // Rating Badge
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.star_fill,
                              color: Color(0xFFFF9500),
                              size: 15,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '4.8',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Share Button
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                          onPressed: () => _showShareSheet(course),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              CupertinoIcons.share,
                              size: 18,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // CTA Button
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: const Size(36, 36),
                          color: isFree
                              ? const Color(0xFF34C759)
                              : const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(18),
                          onPressed: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) =>
                                    CourseDetailScreen(course: course),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isFree ? 'Enroll Free' : 'View Course',
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.play_circle_fill,
              size: 48,
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
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: const Color(0xFF8E8E93),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3C3C43),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Empty State ====================
  Widget _buildEmptyState() {
    IconData emptyIcon;
    String emptyTitle;
    String emptySubtitle;
    String buttonText;
    VoidCallback onButtonTap;

    if (_searchQuery.trim().isNotEmpty) {
      emptyIcon = CupertinoIcons.search;
      emptyTitle = 'No Matches Found';
      emptySubtitle =
          'No courses matched "$_searchQuery". Check spelling or search a different subject.';
      buttonText = 'Clear Search';
      onButtonTap = () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      };
    } else if (_selectedSegment == 1) {
      emptyIcon = CupertinoIcons.gift;
      emptyTitle = 'No Free Courses Currently';
      emptySubtitle =
          'Free courses are added periodically. Check out our full course catalog.';
      buttonText = 'Browse All Courses';
      onButtonTap = () {
        setState(() {
          _selectedSegment = 0;
        });
      };
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
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                emptyIcon,
                size: 38,
                color: const Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: const Color(0xFF007AFF),
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

  // ==================== Error View ====================
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
              color: Color(0xFFFF3B30),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could Not Load Courses',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Please check your internet connection.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: const Color(0xFF007AFF),
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

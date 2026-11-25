import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/course.dart';
import '../registration/login_screen.dart';
import 'course_detail_screen.dart';
import 'courses_screen.dart';

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLoggedIn = false;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedSegment = 0; // 0: All, 1: In Progress, 2: Completed

  @override
  void initState() {
    super.initState();
    _loadMyCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _isLoggedIn = await ApiService.isLoggedIn();

      if (!_isLoggedIn) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final response = await ApiService.getMyCourses();

      if (response['success'] == true) {
        final List<dynamic> coursesData = response['data'] is List
            ? response['data']
            : (response['data']?['courses'] ?? []);

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
          _errorMessage = 'Network Error: Unable to connect to server';
          _isLoading = false;
        });
      }
    }
  }

  // Filtered courses based on segment & search query
  List<Course> get _filteredCourses {
    return _courses.where((course) {
      final progress = course.progress ?? 0;

      // 1. Segment filter
      if (_selectedSegment == 1 && progress >= 100) {
        return false; // In Progress tab
      } else if (_selectedSegment == 2 && progress < 100) {
        return false; // Completed tab
      }

      // 2. Search filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final titleMatch = course.title.toLowerCase().contains(query);
        final descMatch = course.description.toLowerCase().contains(query);
        if (!titleMatch && !descMatch) return false;
      }

      return true;
    }).toList();
  }

  int get _allCount => _courses.length;
  int get _inProgressCount =>
      _courses.where((c) => (c.progress ?? 0) < 100).length;
  int get _completedCount =>
      _courses.where((c) => (c.progress ?? 0) >= 100).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. iOS Header
            _buildIosHeader(),

            // If logged in, show search and segmented control
            if (_isLoggedIn && !_isLoading && _errorMessage == null && _courses.isNotEmpty) ...[
              _buildSearchBar(),
              _buildSegmentedTabs(),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFE5E5EA),
              ),
            ],

            // 2. Content Area
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== iOS Header ====================
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
                      'My Courses',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Continue your learning & track course progress',
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
              if (_isLoggedIn)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  onPressed: _loadMyCourses,
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

  // ==================== Search Bar ====================
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search my courses...',
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

  // ==================== Segmented Tabs ====================
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
              1: _buildSegmentItem('In Progress', _inProgressCount, 1),
              2: _buildSegmentItem('Completed', _completedCount, 2),
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

  // ==================== Body View ====================
  Widget _buildBody() {
    // 1. Not Logged In View
    if (!_isLoggedIn) {
      return _buildNotLoggedInView();
    }

    // 2. Loading State
    if (_isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14),
      );
    }

    // 3. Error State
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    // 4. Empty Courses State
    if (_courses.isEmpty) {
      return _buildEmptyEnrolledView();
    }

    // 5. Filtered Courses Empty
    final list = _filteredCourses;
    if (list.isEmpty) {
      return _buildEmptyFilterView();
    }

    // 6. Main Enrolled Courses List
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _loadMyCourses,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final course = list[index];
                return _buildMyCourseCard(course);
              },
              childCount: list.length,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== iOS Enrolled Course Card ====================
  Widget _buildMyCourseCard(Course course) {
    final int progress = course.progress ?? 0;
    final bool isCompleted = progress >= 100;

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
              // 1. Thumbnail with progress tag
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: course.thumbnail != null &&
                              course.thumbnail!.isNotEmpty
                          ? Image.network(
                              course.thumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildThumbnailPlaceholder(course),
                            )
                          : _buildThumbnailPlaceholder(course),
                    ),
                  ),

                  // Progress Badge Overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted
                                ? CupertinoIcons.checkmark_alt_circle_fill
                                : CupertinoIcons.play_circle_fill,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCompleted ? 'COMPLETED' : '$progress% DONE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Course Info & Progress Section
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
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.3,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Progress Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Course Progress',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        Text(
                          '$progress%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? const Color(0xFF34C759)
                                : const Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (progress.clamp(0, 100)) / 100,
                        backgroundColor: const Color(0xFFF2F2F7),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted
                              ? const Color(0xFF34C759)
                              : const Color(0xFF007AFF),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bottom Row: Completed lessons & Continue Button
                    Row(
                      children: [
                        if (course.completedVideos != null &&
                            course.totalVideos != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.play_circle,
                                size: 14,
                                color: Color(0xFF8E8E93),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${course.completedVideos}/${course.totalVideos} Lessons',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3C3C43),
                                ),
                              ),
                            ],
                          )
                        else
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.book,
                                size: 14,
                                color: Color(0xFF8E8E93),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Full Syllabus Access',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3C3C43),
                                ),
                              ),
                            ],
                          ),

                        const Spacer(),

                        // Continue Button
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: const Size(36, 36),
                          color: isCompleted
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
                                isCompleted ? 'Review' : 'Continue',
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

  // ==================== Not Logged In View ====================
  Widget _buildNotLoggedInView() {
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
              child: const Icon(
                CupertinoIcons.person_crop_circle_badge_exclam,
                size: 40,
                color: Color(0xFF007AFF),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sign In Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Please login to access your enrolled courses, video lectures, and track your learning progress.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(18),
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const CoursesScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Explore Courses',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(18),
                  onPressed: () async {
                    final loggedIn = await Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                    if (loggedIn == true) {
                      _loadMyCourses();
                    }
                  },
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 14,
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
    );
  }

  // ==================== Empty Enrolled State ====================
  Widget _buildEmptyEnrolledView() {
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
              child: const Icon(
                CupertinoIcons.book_fill,
                size: 38,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Enrolled Courses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'You have not enrolled in any courses yet. Browse our comprehensive video courses to kickstart your preparation.',
              style: TextStyle(
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
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const CoursesScreen(),
                  ),
                );
              },
              child: const Text(
                'Browse Courses',
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

  // ==================== Filter Empty State ====================
  Widget _buildEmptyFilterView() {
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
              child: const Icon(
                CupertinoIcons.search,
                size: 38,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Matches Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No enrolled course matched "$_searchQuery".'
                  : 'No courses found in this tab.',
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
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedSegment = 0;
                });
              },
              child: const Text(
                'Show All Enrolled',
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
              onPressed: _loadMyCourses,
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

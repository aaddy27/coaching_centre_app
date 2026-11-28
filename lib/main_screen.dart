import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'includes/main_layout.dart';
import 'models/course.dart';
import 'models/test_series_models.dart';
import 'models/video.dart';
import 'registration/login_screen.dart';
import 'screens/company_info_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/my_courses_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/purchase_history_screen.dart';
import 'screens/test_series/test_history_screen.dart';
import 'screens/test_series/test_series_subjects_screen.dart';
import 'screens/tests_screen.dart';
import 'screens/video_player_screen.dart';
import 'services/api_service.dart';
import 'widgets/ios_components.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  final ValueNotifier<int> _refreshNotifier = ValueNotifier<int>(0);
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeContent(
        onNavigateTab: _onNavItemTapped,
        refreshNotifier: _refreshNotifier,
      ),
      const CoursesScreen(),
      MyCoursesScreen(refreshNotifier: _refreshNotifier),
      const ProfileScreen(),
      const TestsScreen(),
    ];
  }

  @override
  void dispose() {
    _refreshNotifier.dispose();
    super.dispose();
  }

  Future<void> _onNavItemTapped(int index) async {
    if (index == 3) {
      final isLoggedIn = await ApiService.isLoggedIn();
      if (!mounted) return;

      if (!isLoggedIn) {
        _showLoginRequiredDialog();
        return;
      }
    }

    if (index == 0 || index == 2) {
      _refreshNotifier.value++;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _showLoginRequiredDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Sign In Required'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Sign in to access your profile, test history, and purchases.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.pop(dialogContext);
                final loggedIn = await Navigator.push<bool>(
                  context,
                  CupertinoPageRoute(builder: (_) => const LoginScreen()),
                );
                if (loggedIn == true && mounted) {
                  _refreshNotifier.value++;
                  setState(() => _currentIndex = 3);
                }
              },
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          showIosToast(
            context,
            title: 'Exit App',
            message: 'Press back again to exit Olive Learnings.',
            icon: CupertinoIcons.info_circle_fill,
            iconColor: IosTheme.primaryBlue,
            duration: const Duration(seconds: 2),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: MainLayout(
        currentIndex: _currentIndex,
        onNavItemTapped: _onNavItemTapped,
        child: _screens[_currentIndex],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final ValueListenable<int>? refreshNotifier;

  const HomeContent({super.key, this.onNavigateTab, this.refreshNotifier});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  int _currentSliderIndex = 0;
  late final PageController _pageController;
  Timer? _sliderTimer;

  List<Course> _courses = [];
  bool _isLoadingCourses = true;
  String? _coursesError;

  String? _userName;
  bool _isLoggedIn = false;
  Course? _inProgressCourse;
  int _myCoursesCount = 0;
  TestSeries? _featuredTestSeries;
  Map<String, dynamic>? _lastWatchedData;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.93);
    widget.refreshNotifier?.addListener(_handleExternalRefresh);
    _loadAllHomeData();
    _scheduleSlider();
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    widget.refreshNotifier?.removeListener(_handleExternalRefresh);
    _pageController.dispose();
    super.dispose();
  }

  void _handleExternalRefresh() {
    _loadAllHomeData(showSpinner: false);
  }

  void _scheduleSlider() {
    _sliderTimer?.cancel();
    _sliderTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final count = _courses.length > 3 ? 3 : _courses.length;
      if (count <= 1) return;
      final nextIndex = (_pageController.page?.round() ?? 0) + 1;
      _pageController.animateToPage(
        nextIndex % count,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _loadAllHomeData({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoadingCourses = true;
        _coursesError = null;
      });
    }

    // 0. Load last watched video for floating Continue Watching popup
    ApiService.getLastWatchedVideo()
        .then((lastWatched) {
          if (!mounted) return;
          setState(() {
            _lastWatchedData = lastWatched;
          });
        })
        .catchError((_) {});

    // 1. Auth & student-specific data
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = loggedIn;
          if (!loggedIn) {
            _userName = null;
            _inProgressCourse = null;
            _myCoursesCount = 0;
          }
        });
      }

      if (loggedIn) {
        ApiService.getProfile()
            .then((profileRes) {
              if (!mounted) return;
              if (profileRes['success'] == true && profileRes['data'] != null) {
                final user = profileRes['data']['user'] ?? profileRes['data'];
                if (user is Map && user['name'] != null) {
                  setState(() {
                    _userName = user['name'].toString();
                  });
                }
              }
            })
            .catchError((e) {
              debugPrint('Error loading home profile: $e');
            });

        ApiService.getMyCourses()
            .then((myCoursesRes) async {
              if (!mounted) return;
              if (myCoursesRes['success'] == true &&
                  myCoursesRes['data'] != null) {
                final raw = myCoursesRes['data'];
                final List<dynamic> coursesData = raw is List
                    ? raw
                    : (raw is Map && raw['courses'] is List
                          ? raw['courses']
                          : []);
                try {
                  final localSummary =
                      await ApiService.getCourseProgressSummaryMap();
                  final myCourses = coursesData.map((json) {
                    final c = Course.fromJson(json);
                    final local = localSummary[c.id];
                    if (local == null) return c;
                    final lp = local['progress'] ?? 0;
                    final serverProg = c.progress ?? 0;
                    return c.copyWithProgress(
                      progress: lp > serverProg ? lp : c.progress,
                      completedVideos: local['completed_videos'],
                      totalVideos: local['total_videos'],
                    );
                  }).toList();
                  if (mounted) {
                    setState(() {
                      _inProgressCourse = myCourses.isNotEmpty
                          ? myCourses.first
                          : null;
                      _myCoursesCount = myCourses.length;
                    });
                  }
                } catch (e) {
                  debugPrint('Error parsing my courses: $e');
                }
              }
            })
            .catchError((e) {
              debugPrint('Error loading my courses: $e');
            });
      }
    } catch (e) {
      debugPrint('Error checking auth in home: $e');
    }

    // 2. Featured Test Series from GET /test-series
    ApiService.getTestSeriesList()
        .then((res) {
          if (!mounted) return;
          if (res['success'] == true && res['data'] != null) {
            final raw = res['data'];
            final List<dynamic> list = raw is List
                ? raw
                : (raw is Map && raw['data'] is List
                      ? raw['data']
                      : (raw is Map && raw['test_series'] is List
                            ? raw['test_series']
                            : []));
            if (list.isNotEmpty) {
              try {
                setState(() {
                  _featuredTestSeries = TestSeries.fromJson(list.first);
                });
              } catch (e) {
                debugPrint('Error parsing featured test series: $e');
              }
            }
          }
        })
        .catchError((e) {
          debugPrint('Error loading test series for home: $e');
        });

    // 3. Courses Catalog from GET /courses
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

        final parsedCourses = coursesData
            .map((json) => Course.fromJson(json))
            .toList();
        setState(() {
          _courses = parsedCourses;
          _isLoadingCourses = false;
          _coursesError = null;
        });
      } else {
        setState(() {
          _coursesError = ApiService.extractErrorMessage(
            response,
            fallback: 'Failed to load courses',
          );
          _isLoadingCourses = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coursesError = 'Unable to connect to server';
        _isLoadingCourses = false;
      });
    }
  }

  Future<void> _openLogin() async {
    final loggedIn = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (_) => const LoginScreen()),
    );
    if (loggedIn == true && mounted) {
      _loadAllHomeData(showSpinner: false);
    }
  }

  Future<void> _openProtectedScreen(Widget screen) async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      final result = await Navigator.push<bool>(
        context,
        CupertinoPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted || result != true) return;
      _loadAllHomeData(showSpinner: false);
    }
    if (!mounted) return;
    Navigator.push(context, CupertinoPageRoute(builder: (_) => screen));
  }

  IconData _getCourseIcon(Course course) {
    final lowerTitle = course.title.toLowerCase();
    if (lowerTitle.contains('math') ||
        lowerTitle.contains('calculus') ||
        lowerTitle.contains('algebra')) {
      return CupertinoIcons.function;
    } else if (lowerTitle.contains('physic') ||
        lowerTitle.contains('mechanic')) {
      return CupertinoIcons.bolt_fill;
    } else if (lowerTitle.contains('chem')) {
      return CupertinoIcons.flame_fill;
    } else if (lowerTitle.contains('bio') ||
        lowerTitle.contains('life') ||
        lowerTitle.contains('botany')) {
      return CupertinoIcons.leaf_arrow_circlepath;
    } else if (lowerTitle.contains('computer') || lowerTitle.contains('it')) {
      return CupertinoIcons.device_laptop;
    }
    return CupertinoIcons.book_fill;
  }

  Color _getCourseColor(Course course, int index) {
    final lowerTitle = course.title.toLowerCase();
    if (lowerTitle.contains('math')) return IosTheme.primaryBlue;
    if (lowerTitle.contains('physic')) return IosTheme.systemIndigo;
    if (lowerTitle.contains('chem')) return IosTheme.systemOrange;
    if (lowerTitle.contains('bio')) return IosTheme.systemGreen;
    const colors = [
      IosTheme.primaryBlue,
      IosTheme.systemIndigo,
      IosTheme.systemOrange,
      IosTheme.systemGreen,
      IosTheme.systemPurple,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasLastWatched = _lastWatchedData != null;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await _loadAllHomeData(showSpinner: false);
          },
          color: IosTheme.primaryBlue,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildGreetingHeader(),
                const SizedBox(height: 16),
                _buildContinueLearningCard(),
                if (_courses.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildFeaturedCarousel(),
                  if (_courses.length > 1) ...[
                    const SizedBox(height: 10),
                    _buildSliderIndicators(),
                  ],
                ],
                const SizedBox(height: 22),
                _buildQuickActionsSection(),
                const SizedBox(height: 22),
                _buildFeaturedTestSeriesCard(),
                const SizedBox(height: 24),
                _buildCoursesSection(),
                const SizedBox(height: 22),
                _buildCompanyPromoCard(),
                SizedBox(height: hasLastWatched ? 116 : 36),
              ],
            ),
          ),
        ),
        if (hasLastWatched)
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: _buildLastWatchedPopup(),
          ),
      ],
    );
  }

  String _formatWatchedTime(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final mins = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mins:$secs';
    return '$mins:$secs';
  }

  Widget _buildLastWatchedPopup() {
    final data = _lastWatchedData!;
    final videoJson = data['video'];
    if (videoJson is! Map) return const SizedBox.shrink();

    final video = Video.fromJson(Map<String, dynamic>.from(videoJson));
    final watchedSecs =
        int.tryParse('${data['watched_seconds'] ?? video.watchedSeconds}') ?? 0;
    final progress =
        (int.tryParse('${data['progress'] ?? video.watchProgress}') ?? 0).clamp(
          0,
          100,
        );
    final completed =
        data['completed'] == true || video.isWatched || progress >= 95;
    final courseId = int.tryParse(
      '${data['course_id'] ?? video.courseId ?? ''}',
    );
    final courseTitle = data['course_title']?.toString();

    final statusText = completed
        ? 'Completed (100%) • Rewatch lecture'
        : 'Watched up to ${_formatWatchedTime(watchedSecs)} ($progress%)';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: IosTheme.primaryBlue.withValues(alpha: 0.28),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: completed
                            ? IosTheme.systemGreen
                            : IosTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        completed
                            ? CupertinoIcons.checkmark_alt_circle_fill
                            : CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseTitle != null && courseTitle.isNotEmpty
                                ? 'RESUME • ${courseTitle.toUpperCase()}'
                                : 'LAST WATCHED LECTURE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: completed
                                  ? IosTheme.systemGreen
                                  : IosTheme.primaryBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.labelPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: IosTheme.labelTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      minimumSize: const Size(44, 32),
                      color: completed
                          ? IosTheme.systemGreen
                          : IosTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => VideoPlayerScreen(
                              video: video,
                              courseId: courseId,
                              courseTitle: courseTitle,
                              hasPurchased: true,
                            ),
                          ),
                        ).then((_) => _loadAllHomeData(showSpinner: false));
                      },
                      child: Text(
                        completed ? 'Rewatch' : 'Continue',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        await ApiService.dismissLastWatchedVideo();
                        if (mounted) {
                          setState(() => _lastWatchedData = null);
                        }
                      },
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 20,
                        color: Color(0xFFC7C7CC),
                      ),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: progress / 100.0,
                minHeight: 3.5,
                backgroundColor: IosTheme.groupedBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completed ? IosTheme.systemGreen : IosTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyPromoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IosSectionLabel('Technology Partner'),
          IosGroupedCard(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const CompanyInfoScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: IosTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Center(
                            child: Text(
                              'CIS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                CompanyInfoScreen.companyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.labelPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${CompanyInfoScreen.ownerName} • ${CompanyInfoScreen.mobileNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: IosTheme.labelTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                CompanyInfoScreen.officeAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: IosTheme.labelTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final displayName = _userName != null && _userName!.trim().isNotEmpty
        ? _userName!.trim()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName != null
                      ? 'HELLO, ${displayName.toUpperCase()}'
                      : 'STUDENT DASHBOARD',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.labelTertiary,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  displayName != null
                      ? 'Welcome back, $displayName'
                      : 'Ready to Learn Today?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.labelPrimary,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_isLoggedIn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: IosTheme.separator, width: 0.6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 13,
                    color: IosTheme.systemGreen,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Signed In',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: IosTheme.labelPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(44, 32),
              color: IosTheme.primaryBlue,
              borderRadius: BorderRadius.circular(14),
              onPressed: _openLogin,
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContinueLearningCard() {
    final hasEnrolled = _inProgressCourse != null;
    final course = _inProgressCourse;
    final accent = hasEnrolled
        ? _getCourseColor(course!, 0)
        : IosTheme.primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IosSectionLabel(hasEnrolled ? 'Continue Learning' : 'My Learning'),
          IosGroupedCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              hasEnrolled
                                  ? _getCourseIcon(course!)
                                  : CupertinoIcons.book_fill,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasEnrolled
                                    ? course!.title
                                    : (_isLoggedIn
                                          ? 'No Enrolled Courses Yet'
                                          : 'Explore Courses & Mock Tests'),
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.labelPrimary,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasEnrolled
                                    ? '${course!.examBoard?.name ?? 'Enrolled'} • $_myCoursesCount active course${_myCoursesCount > 1 ? 's' : ''}'
                                    : 'HD video lectures, notes & exam test series',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: IosTheme.labelTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          minimumSize: const Size(44, 34),
                          color: IosTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(16),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (hasEnrolled) {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) =>
                                      CourseDetailScreen(course: course!),
                                ),
                              ).then(
                                (_) => _loadAllHomeData(showSpinner: false),
                              );
                            } else {
                              widget.onNavigateTab?.call(1);
                            }
                          },
                          child: Text(
                            hasEnrolled ? 'Resume' : 'Explore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasEnrolled && course!.progress != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (course.progress!.clamp(0, 100)) / 100.0,
                          backgroundColor: IosTheme.groupedBg,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel() {
    final count = _courses.length > 3 ? 3 : _courses.length;
    return SizedBox(
      height: 168,
      child: PageView.builder(
        controller: _pageController,
        itemCount: count,
        onPageChanged: (index) {
          setState(() => _currentSliderIndex = index);
        },
        itemBuilder: (context, index) {
          final course = _courses[index];
          final color = _getCourseColor(course, index);
          final thumb = course.effectiveThumbnail;
          final badge = course.price <= 0
              ? 'FREE COURSE'
              : (course.examBoard?.name.toUpperCase() ?? 'FEATURED');
          final subtitle = course.shortDescription?.isNotEmpty == true
              ? course.shortDescription!
              : (course.price <= 0
                    ? 'Free enrollment • Start learning now'
                    : '₹${course.price.toStringAsFixed(0)} • Complete Syllabus');

          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => CourseDetailScreen(course: course),
                ),
              ).then((_) => _loadAllHomeData(showSpinner: false));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: IosTheme.separator, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null)
                      Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    Container(color: Colors.black.withValues(alpha: 0.45)),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: IosTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            course.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliderIndicators() {
    final count = _courses.length > 3 ? 3 : _courses.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isSelected = _currentSliderIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isSelected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryBlue : const Color(0xFFD1D1D6),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildCompanyPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IosSectionLabel('Powered By'),
          IosGroupedCard(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const CompanyInfoScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: IosTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Center(
                            child: Text(
                              'CIS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CIS Complete It Solution',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.labelPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Deepak Acharya • 5-D-130 JNV Colony, Bikaner',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: IosTheme.labelTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 15,
                          color: Color(0xFFC7C7CC),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IosSectionLabel('Quick Actions'),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionTile(
                  icon: CupertinoIcons.compass_fill,
                  color: IosTheme.primaryBlue,
                  label: 'Courses',
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionTile(
                  icon: CupertinoIcons.doc_checkmark_fill,
                  color: IosTheme.systemIndigo,
                  label: 'Test Series',
                  onTap: () => widget.onNavigateTab?.call(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionTile(
                  icon: CupertinoIcons.doc_chart_fill,
                  color: IosTheme.systemOrange,
                  label: 'Test History',
                  onTap: () => _openProtectedScreen(const TestHistoryScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionTile(
                  icon: CupertinoIcons.bag_fill,
                  color: IosTheme.systemGreen,
                  label: 'Purchases',
                  onTap: () =>
                      _openProtectedScreen(const PurchaseHistoryScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IosTheme.separator, width: 0.6),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: IosTheme.labelPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedTestSeriesCard() {
    final series = _featuredTestSeries;
    final subtitle = series != null
        ? [
            if (series.duration > 0) '${series.duration} Mins',
            if (series.totalMarks > 0)
              '${series.totalMarks.toStringAsFixed(0)} Marks',
            if (series.subjects != null && series.subjects!.isNotEmpty)
              '${series.subjects!.length} Subjects',
          ].join(' • ')
        : 'Simulated CBT mock tests & scorecards';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const IosSectionLabel('Test Series'),
              CupertinoButton(
                padding: const EdgeInsets.only(bottom: 8),
                minimumSize: const Size(44, 24),
                onPressed: () => widget.onNavigateTab?.call(4),
                child: const Text(
                  'All Tests',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: IosTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          IosGroupedCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: IosTheme.systemIndigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_checkmark_fill,
                        color: IosTheme.systemIndigo,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series?.title ?? 'Practice Mock Test Series',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.labelPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle.isNotEmpty
                                ? subtitle
                                : 'Subject-wise mock tests & instant rank',
                            style: const TextStyle(
                              fontSize: 12,
                              color: IosTheme.labelTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      minimumSize: const Size(44, 34),
                      color: IosTheme.systemIndigo,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (series != null) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => TestSeriesSubjectsScreen(
                                testSeriesId: series.id,
                                title: series.title,
                              ),
                            ),
                          );
                        } else {
                          widget.onNavigateTab?.call(4);
                        }
                      },
                      child: Text(
                        series != null ? 'Open' : 'Browse',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const IosSectionLabel('Featured Courses'),
              CupertinoButton(
                padding: const EdgeInsets.only(bottom: 8),
                minimumSize: const Size(44, 24),
                onPressed: () => widget.onNavigateTab?.call(1),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: IosTheme.primaryBlue,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 13,
                      color: IosTheme.primaryBlue,
                    ),
                  ],
                ),
              ),
            ],
          ),
          IosGroupedCard(
            children: [
              if (_isLoadingCourses)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CupertinoActivityIndicator(radius: 12)),
                )
              else if (_coursesError != null && _courses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: IosTheme.labelTertiary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _coursesError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: IosTheme.labelTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: IosTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: _loadAllHomeData,
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_courses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No courses available at the moment.',
                      style: TextStyle(
                        fontSize: 13,
                        color: IosTheme.labelTertiary,
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_courses.length > 5 ? 5 : _courses.length, (
                  index,
                ) {
                  final course = _courses[index];
                  final isLast =
                      index ==
                      ((_courses.length > 5 ? 5 : _courses.length) - 1);
                  final color = _getCourseColor(course, index);
                  final icon = _getCourseIcon(course);
                  final priceText = course.price <= 0
                      ? 'FREE'
                      : '₹${course.price.toStringAsFixed(0)}';
                  final tagText =
                      course.examBoard?.name ??
                      (course.price <= 0 ? 'Free Access' : 'Course');
                  final subtitleText =
                      course.shortDescription?.isNotEmpty == true
                      ? course.shortDescription!
                      : (course.description.isNotEmpty
                            ? course.description
                            : 'Syllabus, notes & video lectures');
                  final metaText =
                      course.subjects != null && course.subjects!.isNotEmpty
                      ? '${course.subjects!.length} subjects'
                      : (course.totalVideos != null && course.totalVideos! > 0
                            ? '${course.totalVideos} videos'
                            : 'Full Course');

                  return Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) =>
                                    CourseDetailScreen(course: course),
                              ),
                            ).then((_) => _loadAllHomeData(showSpinner: false));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Center(
                                    child: Icon(icon, color: color, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              course.title,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: IosTheme.labelPrimary,
                                                letterSpacing: -0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: course.price <= 0
                                                  ? IosTheme.systemGreen
                                                        .withValues(alpha: 0.12)
                                                  : IosTheme.groupedBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              priceText,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: course.price <= 0
                                                    ? IosTheme.systemGreen
                                                    : IosTheme.primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitleText,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: IosTheme.labelTertiary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            metaText,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: IosTheme.labelTertiary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Flexible(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                tagText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: color,
                                                ),
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
                        ),
                      ),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.only(left: 70),
                          child: Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: IosTheme.separator,
                          ),
                        ),
                    ],
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}

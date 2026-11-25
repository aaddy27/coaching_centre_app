import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'includes/main_layout.dart';
import 'screens/profile_screen.dart';
import 'screens/my_courses_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/tests_screen.dart';
import 'registration/login_screen.dart';
import 'services/api_service.dart';
import 'models/course.dart';
import 'screens/course_detail_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  late final Widget _homeContent;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _homeContent = HomeContent(onNavigateTab: _onNavItemTapped);
    _screens = [
      _homeContent,
      const CoursesScreen(),
      const MyCoursesScreen(),
      const ProfileScreen(),
      const TestsScreen(),
    ];
  }

  void _onNavItemTapped(int index) async {
    // Check if user is trying to access profile
    if (index == 3) {
      final isLoggedIn = await ApiService.isLoggedIn();
      
      if (!mounted) return;
      
      if (!isLoggedIn) {
        // Show login required dialog
        _showLoginRequiredDialog();
        return;
      }
    }
    
    setState(() {
      _currentIndex = index;
    });
  }

  void _showLoginRequiredDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Login Required'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('You need to log in to access your profile and account settings.'),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              child: const Text('Log In'),
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

        // If not on Home screen, return to Home screen
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // Already on Home screen: confirm exit with 2-second press window
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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

// ==========================================
// iOS Native Home Content Screen
// ==========================================
class HomeContent extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const HomeContent({super.key, this.onNavigateTab});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  int _currentSliderIndex = 0;
  late PageController _pageController;
  bool _isCheckedIn = false;
  bool _isAudioModeActive = false;
  bool _isAudioPlaying = false;
  String _selectedDoubtSubject = 'Mathematics';
  bool _wifiOnlyDownload = true;

  final List<Map<String, String>> sliderItems = const [
    {
      "image": "assets/images/offer1.jpg",
      "badge": "SCHOLARSHIP 2026",
      "title": "Summer Advanced Batch",
      "subtitle": "Get up to 50% merit discount on full-year prep.",
    },
    {
      "image": "assets/images/offer2.jpg",
      "badge": "MASTERCLASS",
      "title": "Learn from Top Faculty",
      "subtitle": "Interactive doubt sessions and personal mentoring.",
    },
    {
      "image": "assets/images/offer3.jpg",
      "badge": "OFFLINE + APP",
      "title": "Hybrid Coaching Pass",
      "subtitle": "Attend physical classes & revise with app offline vault.",
    },
  ];

  // Real data state
  List<Course> _courses = [];
  bool _isLoadingCourses = true;
  String? _coursesError;
  String? _userName;
  bool _isLoggedIn = false;
  Course? _inProgressCourse;
  int _myCoursesCount = 0;
  Map<String, dynamic>? _latestTest;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.93);
    // Auto-scroll slider
    Future.delayed(const Duration(seconds: 5), _autoScroll);
    _loadAllHomeData();
  }

  Future<void> _loadAllHomeData() async {
    if (mounted) {
      setState(() {
        _isLoadingCourses = true;
        _coursesError = null;
      });
    }

    // 1. Check Login & load profile / enrolled courses
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = loggedIn;
        });
      }

      if (loggedIn) {
        // Load User Profile for dynamic greeting
        ApiService.getProfile().then((profileRes) {
          if (mounted && profileRes['success'] == true && profileRes['data'] != null) {
            final user = profileRes['data']['user'];
            if (user != null && user['name'] != null) {
              setState(() {
                _userName = user['name']?.toString();
              });
            }
          }
        }).catchError((e) {
          debugPrint('Error loading home profile: $e');
        });

        // Load Enrolled Courses for Continue Learning
        ApiService.getMyCourses().then((myCoursesRes) {
          if (mounted && myCoursesRes['success'] == true && myCoursesRes['data'] != null) {
            final List<dynamic> coursesData = myCoursesRes['data'] is List
                ? myCoursesRes['data']
                : (myCoursesRes['data']['courses'] ?? []);
            if (coursesData.isNotEmpty) {
              try {
                final myCourses = coursesData.map((json) => Course.fromJson(json)).toList();
                if (mounted && myCourses.isNotEmpty) {
                  setState(() {
                    _inProgressCourse = myCourses.first;
                    _myCoursesCount = myCourses.length;
                  });
                }
              } catch (e) {
                debugPrint('Error parsing my courses for home: $e');
              }
            }
          }
        }).catchError((e) {
          debugPrint('Error loading my courses for home: $e');
        });
      }
    } catch (e) {
      debugPrint('Error checking auth in home: $e');
    }

    // 2. Load Real Tests
    try {
      ApiService.getAllTests().then((testsRes) {
        if (mounted && testsRes['success'] == true && testsRes['data'] != null) {
          final List<dynamic> testsList = testsRes['data'] is List
              ? testsRes['data']
              : (testsRes['data']['data'] ?? []);
          if (testsList.isNotEmpty && mounted) {
            setState(() {
              _latestTest = testsList.first;
            });
          }
        }
      }).catchError((e) {
        debugPrint('Error loading tests for home: $e');
      });
    } catch (e) {
      debugPrint('Error calling tests for home: $e');
    }

    // 3. Load Real Featured Courses
    try {
      final response = await ApiService.getAllCourses();
      if (!mounted) return;

      if (response['success'] == true || response['success'] == 1 || response['success'] == '1') {
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

        final parsedCourses = coursesData.map((json) => Course.fromJson(json)).toList();
        setState(() {
          _courses = parsedCourses;
          _isLoadingCourses = false;
        });
      } else {
        setState(() {
          _coursesError = response['message'] ?? 'Failed to load courses';
          _isLoadingCourses = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _coursesError = 'Unable to connect to server';
        _isLoadingCourses = false;
      });
    }
  }

  IconData _getCourseIcon(Course course) {
    final lowerTitle = course.title.toLowerCase();
    if (lowerTitle.contains('math') || lowerTitle.contains('calculus') || lowerTitle.contains('algebra')) {
      return CupertinoIcons.function;
    } else if (lowerTitle.contains('physic') || lowerTitle.contains('mechanic')) {
      return CupertinoIcons.bolt_fill;
    } else if (lowerTitle.contains('chem')) {
      return CupertinoIcons.flame_fill;
    } else if (lowerTitle.contains('bio') || lowerTitle.contains('life') || lowerTitle.contains('botany')) {
      return CupertinoIcons.leaf_arrow_circlepath;
    } else if (lowerTitle.contains('ldc') || lowerTitle.contains('patwar') || lowerTitle.contains('ras') || lowerTitle.contains('exam')) {
      return CupertinoIcons.briefcase_fill;
    } else if (lowerTitle.contains('computer') || lowerTitle.contains('ia') || lowerTitle.contains('it')) {
      return CupertinoIcons.device_laptop;
    }
    return CupertinoIcons.book_fill;
  }

  Color _getCourseColor(Course course, int index) {
    final lowerTitle = course.title.toLowerCase();
    if (lowerTitle.contains('math')) {
      return const Color(0xFF007AFF); // Apple Blue
    } else if (lowerTitle.contains('physic')) {
      return const Color(0xFF5856D6); // Apple Indigo
    } else if (lowerTitle.contains('chem')) {
      return const Color(0xFFFF9500); // Apple Orange
    } else if (lowerTitle.contains('bio')) {
      return const Color(0xFF34C759); // Apple Green
    } else if (lowerTitle.contains('ldc') || lowerTitle.contains('patwar') || lowerTitle.contains('ras')) {
      return const Color(0xFFAF52DE); // Apple Purple
    }
    const colors = [
      Color(0xFF007AFF),
      Color(0xFF5856D6),
      Color(0xFFFF9500),
      Color(0xFF34C759),
      Color(0xFFAF52DE),
      Color(0xFFFF2D55),
    ];
    return colors[index % colors.length];
  }

  void _autoScroll() {
    if (mounted && _pageController.hasClients) {
      final count = _courses.isNotEmpty ? (_courses.length > 3 ? 3 : _courses.length) : sliderItems.length;
      final nextIndex = (_pageController.page?.round() ?? 0) + 1;
      _pageController.animateToPage(
        nextIndex % count,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleDailyCheckIn() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isCheckedIn = !_isCheckedIn;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _isCheckedIn ? 'Daily streak updated! +25 Study XP' : 'Check-in reverted',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: _isCheckedIn ? const Color(0xFF34C759) : const Color(0xFF1C1C1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleAudioMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isAudioModeActive = !_isAudioModeActive;
      if (_isAudioModeActive) {
        _isAudioPlaying = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.headphones, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _isAudioModeActive
                  ? 'Audio Commute Mode Active (Plays when phone is locked)'
                  : 'Audio Mode Disabled',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFAF52DE),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await _loadAllHomeData();
      },
      color: const Color(0xFF007AFF),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),

            // 1. Welcome & Greeting Row
            _buildGreetingHeader(),

            const SizedBox(height: 14),

            // 2. Daily Study Streak & Goal Ring Widget (Apple Fitness Style)
            _buildStudyStreakCard(),

            const SizedBox(height: 20),

            // 3. APP-ONLY SUPERPOWERS BAR (Functions only on Mobile App)
            _buildAppOnlyFeaturesSection(),

            // 4. Background Audio Lecture Mini-Player (if enabled)
            if (_isAudioModeActive) ...[
              const SizedBox(height: 14),
              _buildAudioMiniPlayer(),
            ],

            const SizedBox(height: 22),

            // 5. In-Progress Lecture (Continue Learning)
            _buildContinueLearningCard(),

            const SizedBox(height: 22),

            // 6. Editorial Hero Announcements Carousel
            _buildHeroSlider(),

            const SizedBox(height: 8),

            // Carousel Indicators
            _buildSliderIndicators(),

            const SizedBox(height: 24),

            // 7. Daily Mock Test Challenge
            _buildDailyMockTestCard(),

            const SizedBox(height: 26),

            // 8. Featured & Popular Courses
            _buildCoursesSection(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final displayName = _userName != null && _userName!.trim().isNotEmpty ? _userName!.trim() : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName != null ? 'HELLO, ${displayName.toUpperCase()}' : 'STUDENT DASHBOARD',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8E8E93),
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  displayName != null ? 'Welcome back, $displayName' : 'Ready to Excel Today?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _isLoggedIn ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isLoggedIn ? 'Online Sync' : 'Guest Mode',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyStreakCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _isCheckedIn ? 1.0 : (_myCoursesCount > 0 ? 0.75 : 0.4),
                  strokeWidth: 5,
                  backgroundColor: const Color(0xFFF2F2F7),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isCheckedIn ? const Color(0xFF34C759) : const Color(0xFF007AFF),
                  ),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    _isCheckedIn ? '100%' : (_myCoursesCount > 0 ? '75%' : '40%'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isCheckedIn
                          ? 'Daily Streak Active'
                          : (_myCoursesCount > 0
                              ? '$_myCoursesCount Enrolled Course${_myCoursesCount > 1 ? "s" : ""}'
                              : 'Daily Study Streak'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _isCheckedIn
                      ? 'Attendance marked today • Keep going!'
                      : (_myCoursesCount > 0
                          ? 'Continue your lessons and complete daily goals'
                          : 'Mark daily attendance to build your learning streak'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _handleDailyCheckIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _isCheckedIn ? const Color(0xFF34C759) : const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isCheckedIn ? CupertinoIcons.checkmark : CupertinoIcons.bolt_fill,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isCheckedIn ? 'Done' : 'Check In',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppOnlyFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'APP-ONLY FEATURES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MOBILE EXCLUSIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildAppFeatureItem(
                  icon: CupertinoIcons.camera_viewfinder,
                  color: const Color(0xFF007AFF),
                  label: 'Snap Doubt',
                  sublabel: 'Camera AI',
                  onTap: () => _openDoubtSnapSheet(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAppFeatureItem(
                  icon: CupertinoIcons.arrow_down_circle_fill,
                  color: const Color(0xFF34C759),
                  label: 'Offline Vault',
                  sublabel: 'No Internet',
                  onTap: () => _openOfflineVaultSheet(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAppFeatureItem(
                  icon: CupertinoIcons.headphones,
                  color: const Color(0xFFAF52DE),
                  label: 'Audio Mode',
                  sublabel: 'Commute Safe',
                  onTap: _toggleAudioMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAppFeatureItem(
                  icon: CupertinoIcons.qrcode_viewfinder,
                  color: const Color(0xFFFF9500),
                  label: 'QR Check-in',
                  sublabel: 'Attendance',
                  onTap: () => _openQrScannerSheet(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppFeatureItem({
    required IconData icon,
    required Color color,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMiniPlayer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFAF52DE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.waveform,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physics • Lecture 12: Electromagnetic Waves',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  '🎧 Audio Commute Mode (Screen Lock Safe)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFAF52DE),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(34, 34),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isAudioPlaying = !_isAudioPlaying;
              });
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isAudioPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                size: 16,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isAudioModeActive = false;
              });
            },
            child: const Icon(
              CupertinoIcons.xmark,
              size: 16,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearningCard() {
    final hasEnrolledCourse = _inProgressCourse != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            hasEnrolledCourse ? 'CONTINUE LEARNING' : 'START LEARNING',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: hasEnrolledCourse
                          ? _getCourseColor(_inProgressCourse!, 0)
                          : const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(9.5),
                    ),
                    child: Center(
                      child: Icon(
                        hasEnrolledCourse
                            ? _getCourseIcon(_inProgressCourse!)
                            : CupertinoIcons.book_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasEnrolledCourse
                              ? _inProgressCourse!.title
                              : 'Explore High Quality Courses',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasEnrolledCourse
                              ? '${_inProgressCourse!.examBoard?.name ?? 'Enrolled Batch'} • ${_inProgressCourse!.subjects?.length ?? _inProgressCourse!.totalSubjects ?? 0} Subjects Available'
                              : 'Video lectures, notes & test series for competitive exams',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (hasEnrolledCourse) {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => CourseDetailScreen(course: _inProgressCourse!),
                          ),
                        );
                      } else {
                        widget.onNavigateTab?.call(1); // Go to Courses Tab
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasEnrolledCourse ? CupertinoIcons.play_fill : CupertinoIcons.compass_fill,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasEnrolledCourse ? 'Resume' : 'Explore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (hasEnrolledCourse) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ((_inProgressCourse!.progress ?? 35) / 100.0).clamp(0.05, 1.0),
                    backgroundColor: const Color(0xFFF2F2F7),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getCourseColor(_inProgressCourse!, 0),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSlider() {
    final count = _courses.isNotEmpty ? (_courses.length > 3 ? 3 : _courses.length) : sliderItems.length;
    return SizedBox(
      height: 175,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentSliderIndex = index % count;
          });
        },
        itemBuilder: (context, index) {
          final slideIndex = index % count;
          final hasCourse = _courses.isNotEmpty && slideIndex < _courses.length;
          final course = hasCourse ? _courses[slideIndex] : null;

          final imageAsset = sliderItems[slideIndex % sliderItems.length]["image"]!;
          final badge = hasCourse
              ? (course!.price <= 0 ? "FREE COURSE" : (course.examBoard?.name ?? "FEATURED BATCH"))
              : sliderItems[slideIndex % sliderItems.length]["badge"]!;
          final title = hasCourse
              ? course!.title
              : sliderItems[slideIndex % sliderItems.length]["title"]!;
          final subtitle = hasCourse
              ? (course!.shortDescription?.isNotEmpty == true
                  ? course.shortDescription!
                  : (course.price <= 0 ? 'Free enrollment now • Start learning' : 'Price: ₹${course.price.toStringAsFixed(0)} • Full Syllabus'))
              : sliderItems[slideIndex % sliderItems.length]["subtitle"]!;

          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              if (course != null) {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => CourseDetailScreen(course: course),
                  ),
                );
              } else {
                widget.onNavigateTab?.call(1);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      imageAsset,
                      fit: BoxFit.cover,
                    ),
                    // Dark scrim for readability without rainbow gradients
                    Container(
                      color: Colors.black.withValues(alpha: 0.42),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
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
    final count = _courses.isNotEmpty ? (_courses.length > 3 ? 3 : _courses.length) : sliderItems.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) {
          final isSelected = _currentSliderIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isSelected ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyMockTestCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'TODAY\'S MOCK TEST',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.doc_checkmark_fill,
                    color: Color(0xFF5856D6),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _latestTest != null
                          ? (_latestTest!['title']?.toString() ?? 'Daily Test Booster 2026')
                          : 'Daily Mock Test 2026',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _latestTest != null
                          ? '${_latestTest!['questions_count'] != null && _latestTest!['questions_count'] > 0 ? "${_latestTest!['questions_count']} Questions • " : ""}${_latestTest!['duration_minutes'] ?? _latestTest!['duration'] ?? 15} Mins • ${_latestTest!['total_marks'] != null && _latestTest!['total_marks'] > 0 ? "${_latestTest!['total_marks']} Marks" : "Instant Rank"}'
                          : '10 Questions • 15 Mins • Instant Rank',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onNavigateTab?.call(4); // Switch to Tests Tab
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5856D6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Start Test',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoursesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FEATURED COURSES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.6,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  widget.onNavigateTab?.call(1); // Go to Courses Tab
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 14,
                      color: Color(0xFF007AFF),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          ),
          child: _isLoadingCourses
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 12),
                  ),
                )
              : _coursesError != null && _courses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              color: Color(0xFF8E8E93),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _coursesError!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E8E93),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(8),
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
                  : _courses.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No courses available at the moment.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: List.generate(
                            _courses.length > 5 ? 5 : _courses.length,
                            (index) {
                              final course = _courses[index];
                              final isLast = index == (_courses.length > 5 ? 4 : _courses.length - 1);
                              final color = _getCourseColor(course, index);
                              final icon = _getCourseIcon(course);
                              final priceText = course.price <= 0
                                  ? 'FREE'
                                  : '₹${course.price.toStringAsFixed(0)}';
                              final tagText = course.examBoard?.name ??
                                  (course.price <= 0 ? 'Free Access' : 'Popular');
                              final subtitleText = course.shortDescription?.isNotEmpty == true
                                  ? course.shortDescription!
                                  : (course.description.isNotEmpty
                                      ? course.description
                                      : 'Complete syllabus, notes & video lectures');

                              final studentsCount = course.enrolledStudents != null && course.enrolledStudents! > 0
                                  ? '${course.enrolledStudents} students'
                                  : (course.subjects != null && course.subjects!.isNotEmpty
                                      ? '${course.subjects!.length} subjects'
                                      : (course.totalVideos != null && course.totalVideos! > 0
                                          ? '${course.totalVideos} videos'
                                          : 'Full Course'));

                              return Column(
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (context) => CourseDetailScreen(course: course),
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        course.title,
                                                        style: const TextStyle(
                                                          fontSize: 14.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF1C1C1E),
                                                          letterSpacing: -0.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: course.price <= 0
                                                            ? const Color(0xFF34C759).withValues(alpha: 0.12)
                                                            : const Color(0xFFF2F2F7),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        priceText,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: course.price <= 0
                                                              ? const Color(0xFF34C759)
                                                              : const Color(0xFF007AFF),
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
                                                    color: Color(0xFF8E8E93),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      CupertinoIcons.star_fill,
                                                      size: 13,
                                                      color: Color(0xFFFF9500),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    const Text(
                                                      '4.9',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF1C1C1E),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      studentsCount,
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        color: Color(0xFF8E8E93),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: color.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        tagText,
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: color,
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
                                  if (!isLast)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 70),
                                      child: Divider(
                                        height: 0.5,
                                        thickness: 0.5,
                                        color: Color(0xFFE5E5EA),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  // ============================================================
  // APP-ONLY MODAL SHEETS (Native Mobile Exclusives)
  // ============================================================

  /// 1. Snap Doubt Camera Solver Modal Sheet
  void _openDoubtSnapSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D1D6),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Snap & Solve Doubt',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CAMERA AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(30, 30),
                          onPressed: () => Navigator.pop(context),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5E5EA),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.xmark, size: 15, color: Color(0xFF8E8E93)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Subject Selector Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Mathematics', 'Physics', 'Chemistry', 'Biology'].map((subject) {
                          final isSelected = _selectedDoubtSubject == subject;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setModalState(() => _selectedDoubtSubject = subject);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  subject,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Simulated Live Camera Viewfinder
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Frame brackets
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.viewfinder, color: Colors.white, size: 48),
                                      SizedBox(height: 12),
                                      Text(
                                        'Place question inside this frame',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Auto-focusing text & equations',
                                        style: TextStyle(
                                          color: Color(0xFF8E8E93),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Top Camera Controls
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.bolt_fill, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Shutter Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.photo_on_rectangle, color: Color(0xFF1C1C1E), size: 20),
                          ),
                        ),
                        // Big Shutter Button
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Doubt captured for $_selectedDoubtSubject! AI Tutor analyzing...'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF007AFF),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF007AFF), width: 4),
                            ),
                            child: Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.pencil, color: Color(0xFF1C1C1E), size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 2. Offline Study Vault Modal Sheet
  void _openOfflineVaultSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D1D6),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Offline Study Vault',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LOCAL STORAGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34C759),
                            ),
                          ),
                        ),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(30, 30),
                          onPressed: () => Navigator.pop(context),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5E5EA),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.xmark, size: 15, color: Color(0xFF8E8E93)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Storage info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Internal Storage Used: 1.8 GB',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                              Text(
                                '28.4 GB Free',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: const LinearProgressIndicator(
                              value: 0.18,
                              backgroundColor: Color(0xFFF2F2F7),
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Download on Wi-Fi Only',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                              CupertinoSwitch(
                                value: _wifiOnlyDownload,
                                activeTrackColor: const Color(0xFF34C759),
                                onChanged: (val) {
                                  setModalState(() => _wifiOnlyDownload = val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SAVED LECTURES (AIRPLANE READY)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E8E93),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                        ),
                        child: ListView(
                          children: [
                            _buildOfflineItem(
                              title: 'Physics: Electromagnetism L-01',
                              info: '185 MB • 42 mins • High Quality',
                              isDownloaded: true,
                            ),
                            const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5EA)),
                            _buildOfflineItem(
                              title: 'Chemistry: Reaction Kinetics',
                              info: '220 MB • 55 mins • High Quality',
                              isDownloaded: true,
                            ),
                            const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5EA)),
                            _buildOfflineItem(
                              title: 'Maths: Differential Equations L-04',
                              info: '145 MB • 38 mins • High Quality',
                              isDownloaded: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineItem({
    required String title,
    required String info,
    required bool isDownloaded,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.arrow_down_circle_fill,
                color: Color(0xFF34C759),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  info,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Playing offline from local storage...'),
                  backgroundColor: Color(0xFF34C759),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Play',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF34C759),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Classroom QR Scanner Modal Sheet
  void _openQrScannerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D1D6),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Classroom QR Check-in',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ATTENDANCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9500),
                        ),
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(30, 30),
                      onPressed: () => Navigator.pop(context),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E5EA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.xmark, size: 15, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // QR Scanner Viewfinder
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFFF9500), width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.qrcode_viewfinder, color: Color(0xFFFF9500), size: 54),
                            SizedBox(height: 10),
                            Text(
                              'Scanning...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan the QR code displayed on your classroom entrance or desk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Attendance Marked! Morning Batch • Room 204'),
                          ],
                        ),
                        backgroundColor: const Color(0xFF34C759),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Simulate Instant Check-in',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

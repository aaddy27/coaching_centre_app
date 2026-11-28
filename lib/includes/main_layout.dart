import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/course.dart';
import '../registration/login_screen.dart';
import '../screens/company_info_screen.dart';
import '../screens/course_detail_screen.dart';
import '../screens/purchase_history_screen.dart';
import '../screens/test_series/test_history_screen.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onNavItemTapped;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavItemTapped,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: widget.currentIndex == 0 ? _buildIosNavigationBar() : null,
      body: widget.child,
      bottomNavigationBar: _buildIosBottomNav(),
    );
  }

  /// Native iOS Top Navigation Bar (Apple HIG NavigationBar Standard)
  PreferredSizeWidget _buildIosNavigationBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return PreferredSize(
      preferredSize: Size.fromHeight(50 + topPadding),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Color(0x26000000),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: IosTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.book_fill,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olive Learnings',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: IosTheme.labelPrimary,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 1),
                      Text(
                        'LEARN & GROW',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: IosTheme.labelTertiary,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildIosNavButton(
                  icon: CupertinoIcons.search,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showSearchSheet(context);
                  },
                ),
                const SizedBox(width: 8),
                _buildIosNavButton(
                  icon: CupertinoIcons.square_grid_2x2,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showQuickActivitySheet(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// iOS Bar Button Item (44x44 minimum touch target)
  Widget _buildIosNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: IosTheme.groupedBg,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: IosTheme.labelPrimary,
          ),
        ),
      ),
    );
  }

  /// Native iOS Tab Bar (Apple HIG UITabBar Standard)
  Widget _buildIosBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0x26000000),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 49,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIosTabItem(
                index: 0,
                label: 'Home',
                icon: CupertinoIcons.house,
                activeIcon: CupertinoIcons.house_fill,
              ),
              _buildIosTabItem(
                index: 1,
                label: 'Courses',
                icon: CupertinoIcons.compass,
                activeIcon: CupertinoIcons.compass_fill,
              ),
              _buildIosTabItem(
                index: 4,
                label: 'Tests',
                icon: CupertinoIcons.doc_checkmark,
                activeIcon: CupertinoIcons.doc_checkmark_fill,
              ),
              _buildIosTabItem(
                index: 2,
                label: 'My Courses',
                icon: CupertinoIcons.rectangle_stack,
                activeIcon: CupertinoIcons.rectangle_stack_fill,
              ),
              _buildIosTabItem(
                index: 3,
                label: 'Profile',
                icon: CupertinoIcons.person_crop_circle,
                activeIcon: CupertinoIcons.person_crop_circle_fill,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIosTabItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = widget.currentIndex == index;

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        pressedOpacity: 0.6,
        onPressed: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
          }
          widget.onNavItemTapped(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 23,
              color: isSelected ? IosTheme.primaryBlue : IosTheme.labelTertiary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? IosTheme.primaryBlue
                    : IosTheme.labelTertiary,
                letterSpacing: -0.24,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Quick Shortcuts Sheet (replaces placeholder notifications)
  void _showQuickActivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: IosTheme.groupedBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      'Quick Access',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.labelPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: IosTheme.fillGray,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 15,
                          color: IosTheme.labelTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                IosGroupedCard(
                  children: [
                    _buildQuickRow(
                      icon: CupertinoIcons.compass_fill,
                      iconColor: IosTheme.primaryBlue,
                      title: 'Browse Course Catalog',
                      subtitle: 'Explore video lectures & syllabus',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        widget.onNavItemTapped(1);
                      },
                    ),
                    const Divider(
                      height: 0.5,
                      indent: 60,
                      color: IosTheme.separator,
                    ),
                    _buildQuickRow(
                      icon: CupertinoIcons.doc_checkmark_fill,
                      iconColor: IosTheme.systemIndigo,
                      title: 'Test Series & Mock Exams',
                      subtitle: 'Practice CBT mock papers & solutions',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        widget.onNavItemTapped(4);
                      },
                    ),
                    const Divider(
                      height: 0.5,
                      indent: 60,
                      color: IosTheme.separator,
                    ),
                    _buildQuickRow(
                      icon: CupertinoIcons.doc_chart_fill,
                      iconColor: IosTheme.systemOrange,
                      title: 'My Test History',
                      subtitle: 'Review past scorecards & reports',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openProtectedScreen(const TestHistoryScreen());
                      },
                    ),
                    const Divider(
                      height: 0.5,
                      indent: 60,
                      color: IosTheme.separator,
                    ),
                    _buildQuickRow(
                      icon: CupertinoIcons.bag_fill,
                      iconColor: IosTheme.systemGreen,
                      title: 'Purchase History',
                      subtitle: 'View receipts & order status',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openProtectedScreen(const PurchaseHistoryScreen());
                      },
                    ),
                    const Divider(
                      height: 0.5,
                      indent: 60,
                      color: IosTheme.separator,
                    ),
                    _buildQuickRow(
                      icon: CupertinoIcons.building_2_fill,
                      iconColor: IosTheme.primaryBlue,
                      title: CompanyInfoScreen.companyName,
                      subtitle:
                          '${CompanyInfoScreen.ownerName} • ${CompanyInfoScreen.mobileNumber}',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const CompanyInfoScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProtectedScreen(Widget screen) async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    if (!isLoggedIn) {
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted) return;
      final nowLoggedIn = await ApiService.isLoggedIn();
      if (!mounted || !nowLoggedIn) return;
    }
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildQuickRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: IosTheme.labelPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IosTheme.labelTertiary,
                      ),
                    ),
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
    );
  }

  /// Native iOS Search Sheet wired to GET /courses?search=...
  void _showSearchSheet(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    Timer? debounce;
    bool isSearching = false;
    bool hasSearched = false;
    String? error;
    List<Course> results = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch(String rawQuery) async {
              final q = rawQuery.trim();
              if (q.isEmpty) {
                setSheetState(() {
                  results = [];
                  hasSearched = false;
                  isSearching = false;
                  error = null;
                });
                return;
              }

              setSheetState(() {
                isSearching = true;
                hasSearched = true;
                error = null;
              });

              final res = await ApiService.getAllCourses(search: q);
              if (!sheetContext.mounted) return;

              if (res['success'] == true && res['data'] != null) {
                final raw = res['data'];
                final List list = raw is List
                    ? raw
                    : (raw is Map && raw['courses'] is List
                        ? raw['courses']
                        : []);
                setSheetState(() {
                  results = list.map((e) => Course.fromJson(e)).toList();
                  isSearching = false;
                });
              } else {
                setSheetState(() {
                  error = ApiService.extractErrorMessage(
                    res,
                    fallback: 'Could not search courses.',
                  );
                  isSearching = false;
                });
              }
            }

            void onQueryChanged(String value) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 350), () {
                runSearch(value);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
                ),
                decoration: const BoxDecoration(
                  color: IosTheme.groupedBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                            'Search Courses',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.labelPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              debounce?.cancel();
                              Navigator.pop(sheetContext);
                            },
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: IosTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CupertinoSearchTextField(
                        controller: controller,
                        autofocus: true,
                        placeholder: 'Search courses, subjects, topics...',
                        backgroundColor: IosTheme.fillGray,
                        borderRadius: BorderRadius.circular(10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        onChanged: onQueryChanged,
                        onSubmitted: runSearch,
                        onSuffixTap: () {
                          controller.clear();
                          runSearch('');
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!hasSearched) ...[
                        const Text(
                          'POPULAR TOPICS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: IosTheme.labelTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildIosSearchChip('Physics', () {
                              controller.text = 'Physics';
                              runSearch('Physics');
                            }),
                            _buildIosSearchChip('Chemistry', () {
                              controller.text = 'Chemistry';
                              runSearch('Chemistry');
                            }),
                            _buildIosSearchChip('Mathematics', () {
                              controller.text = 'Mathematics';
                              runSearch('Mathematics');
                            }),
                            _buildIosSearchChip('Biology', () {
                              controller.text = 'Biology';
                              runSearch('Biology');
                            }),
                            _buildIosSearchChip('Test Series', () {
                              debounce?.cancel();
                              Navigator.pop(sheetContext);
                              widget.onNavItemTapped(4);
                            }),
                          ],
                        ),
                      ] else if (isSearching) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: CupertinoActivityIndicator(radius: 13),
                          ),
                        ),
                      ] else if (error != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              error!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: IosTheme.systemRed,
                              ),
                            ),
                          ),
                        ),
                      ] else if (results.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No courses found for "${controller.text.trim()}"',
                              style: const TextStyle(
                                fontSize: 14,
                                color: IosTheme.labelTertiary,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Flexible(
                          child: IosGroupedCard(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 320),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 0.5,
                                    indent: 14,
                                    color: IosTheme.separator,
                                  ),
                                  itemBuilder: (context, idx) {
                                    final course = results[idx];
                                    final priceLabel = course.price <= 0
                                        ? 'FREE'
                                        : '₹${course.price.toStringAsFixed(0)}';
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          debounce?.cancel();
                                          Navigator.pop(sheetContext);
                                          Navigator.push(
                                            this.context,
                                            CupertinoPageRoute(
                                              builder: (_) =>
                                                  CourseDetailScreen(
                                                course: course,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: IosTheme.primaryBlue
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(9),
                                                ),
                                                child: const Icon(
                                                  CupertinoIcons.book_fill,
                                                  color: IosTheme.primaryBlue,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      course.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: IosTheme
                                                            .labelPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      course.examBoard?.name ??
                                                          course.description,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: IosTheme
                                                            .labelTertiary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                priceLabel,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: course.price <= 0
                                                      ? IosTheme.systemGreen
                                                      : IosTheme.primaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      debounce?.cancel();
      controller.dispose();
    });
  }

  Widget _buildIosSearchChip(String label, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IosTheme.separator, width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.arrow_up_right,
              size: 12,
              color: IosTheme.labelTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: IosTheme.labelPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

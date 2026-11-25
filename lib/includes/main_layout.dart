import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      backgroundColor: const Color(0xFFF2F2F7), // Apple iOS System Grouped Background
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
              color: Color(0x26000000), // iOS 0.5pt Hairline separator
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
                // iOS App Squircle Monogram
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF), // Apple System Blue (Solid, No Gradient)
                    borderRadius: BorderRadius.circular(9), // Continuous Apple Squircle
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
                // Navigation Bar Title & Subtitle Hierarchy
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
                          color: Color(0xFF1C1C1E), // Apple System Label
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
                          color: Color(0xFF8E8E93), // Apple Secondary Label
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Trailing Bar Buttons: Search & Notifications
                _buildIosNavButton(
                  icon: CupertinoIcons.search,
                  tooltip: 'Search',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showSearchSheet(context);
                  },
                ),
                const SizedBox(width: 10),
                _buildIosNavButton(
                  icon: CupertinoIcons.bell,
                  tooltip: 'Notifications',
                  badgeCount: 3,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showNotificationsBottomSheet(context);
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
    required String tooltip,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7), // Apple System Gray 6 (Solid, No Gradient)
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                size: 19,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30), // Apple System Red Badge
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Native iOS Tab Bar (Apple HIG UITabBar Standard)
  /// Clean 5-Tab layout, 49pt height + safe area, hairline border, no FAB, no gradients.
  Widget _buildIosBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0x26000000), // iOS Hairline Divider (0.5pt)
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 49, // Exact native iOS UITabBar height
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
                badge: 'New',
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

  /// Individual iOS Tab Item
  Widget _buildIosTabItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    String? badge,
  }) {
    final isSelected = widget.currentIndex == index;
    const activeColor = Color(0xFF007AFF); // Apple System Blue
    const inactiveColor = Color(0xFF8E8E93); // Apple System Inactive Gray

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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 23,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
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

  /// Native iOS Modal Sheet (UISheetPresentationController standard)
  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7), // iOS System Grouped Background
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // iOS Grabber / Drag Indicator
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
                // Header
                Row(
                  children: [
                    const Text(
                      'Notifications',
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
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '3 New',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () => Navigator.pop(context),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E5EA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 15,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Inset Grouped Notifications List
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _buildIosNotificationRow(
                        title: 'New Course Available',
                        subtitle: 'Advanced Flutter Development is now live!',
                        icon: CupertinoIcons.book_fill,
                        iconColor: const Color(0xFF007AFF),
                        time: '2m ago',
                        showDivider: true,
                      ),
                      _buildIosNotificationRow(
                        title: 'Assignment Due',
                        subtitle: 'Submit your project by tomorrow 5 PM',
                        icon: CupertinoIcons.doc_text_fill,
                        iconColor: const Color(0xFFFF9500),
                        time: '1h ago',
                        showDivider: true,
                      ),
                      _buildIosNotificationRow(
                        title: 'Class Reminder',
                        subtitle: 'Live session starts in 30 minutes',
                        icon: CupertinoIcons.videocam_fill,
                        iconColor: const Color(0xFF34C759),
                        time: '25m ago',
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
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

  /// Individual iOS Grouped Notification Row
  Widget _buildIosNotificationRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String time,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 20),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF8E8E93),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 62),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: Color(0xFFE5E5EA),
            ),
          ),
      ],
    );
  }

  /// Native iOS Search Sheet (UISearchController Standard)
  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7), // iOS System Grouped Background
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // iOS Drag Handle
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
                  // Header Row
                  Row(
                    children: [
                      const Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // iOS Search Bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: const Row(
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          color: Color(0xFF8E8E93),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search courses, materials, tests...',
                              hintStyle: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'POPULAR SEARCHES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildIosSearchChip('Mathematics'),
                      _buildIosSearchChip('Physics'),
                      _buildIosSearchChip('Chemistry'),
                      _buildIosSearchChip('Test Series'),
                      _buildIosSearchChip('Calculus'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// iOS Search Chip
  Widget _buildIosSearchChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.arrow_up_right,
            size: 12,
            color: Color(0xFF8E8E93),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

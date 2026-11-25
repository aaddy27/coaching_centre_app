import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../registration/login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'purchase_history_screen.dart';
import 'test_series/test_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getProfile();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _userData = response['data']['user'] ?? response['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load profile';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext sheetContext) => CupertinoActionSheet(
        title: const Text('Log Out'),
        message: const Text(
          'Choose whether to sign out of this device only or all signed-in devices.',
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(sheetContext, 'single'),
            child: const Text('Log Out This Device'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(sheetContext, 'all'),
            child: const Text('Log Out All Devices'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext, null),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CupertinoActivityIndicator(radius: 16),
      ),
    );

    try {
      final response = choice == 'all'
          ? await ApiService.logoutAll()
          : await ApiService.logout();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response['success'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          CupertinoPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showIosToast(
          title: 'Logout Failed',
          message: response['message'] ?? 'Could not log out',
          icon: CupertinoIcons.exclamationmark_circle,
          iconColor: const Color(0xFFFF3B30),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showIosToast(
        title: 'Error',
        message: e.toString(),
        icon: CupertinoIcons.exclamationmark_circle,
        iconColor: const Color(0xFFFF3B30),
      );
    }
  }

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
      backgroundColor: const Color(0xFFF2F2F7), // iOS Grouped Background
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : _errorMessage != null
                ? _buildErrorView()
                : _buildProfileContent(),
      ),
    );
  }

  // ==================== Main Profile View ====================
  Widget _buildProfileContent() {
    final user = _userData ?? {};
    final String name = user['name'] ?? 'Student';
    final String phone = user['phone'] ?? '';
    final String email = user['email'] ?? '';
    final String city = user['city'] ?? 'Not set';
    final String state = user['state'] ?? 'Not set';
    final String role = user['role'] ?? 'Student';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _loadUserProfile,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. iOS Large Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.6,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      onPressed: _loadUserProfile,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE5E5EA),
                            width: 0.5,
                          ),
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
                const SizedBox(height: 16),

                // 2. User Avatar & Summary Card
                _buildUserHeaderCard(
                  name: name,
                  email: email,
                  phone: phone,
                  role: role,
                ),
                const SizedBox(height: 24),

                // 3. Section: Personal Details
                _buildSectionHeader('PERSONAL INFORMATION'),
                const SizedBox(height: 8),
                _buildGroupedCard([
                  _buildDetailRow(
                    icon: CupertinoIcons.mail_solid,
                    iconColor: const Color(0xFF007AFF),
                    label: 'Email Address',
                    value: email.isNotEmpty ? email : 'Not provided',
                  ),
                  const Divider(height: 1, indent: 48, color: Color(0xFFE5E5EA)),
                  _buildDetailRow(
                    icon: CupertinoIcons.phone_fill,
                    iconColor: const Color(0xFF34C759),
                    label: 'Phone Number',
                    value: phone.isNotEmpty ? phone : 'Not provided',
                  ),
                  const Divider(height: 1, indent: 48, color: Color(0xFFE5E5EA)),
                  _buildDetailRow(
                    icon: CupertinoIcons.building_2_fill,
                    iconColor: const Color(0xFFFF9500),
                    label: 'City',
                    value: city,
                  ),
                  const Divider(height: 1, indent: 48, color: Color(0xFFE5E5EA)),
                  _buildDetailRow(
                    icon: CupertinoIcons.map_pin_ellipse,
                    iconColor: const Color(0xFF5856D6),
                    label: 'State',
                    value: state,
                  ),
                ]),
                const SizedBox(height: 24),

                // 4. Section: Learning & Orders Activity
                _buildSectionHeader('LEARNING & ORDERS'),
                const SizedBox(height: 8),
                _buildGroupedCard([
                  _buildActionRow(
                    icon: CupertinoIcons.doc_chart_fill,
                    iconColor: const Color(0xFF5856D6),
                    title: 'My Test History',
                    subtitle: 'View past test attempts, scores & solutions',
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const TestHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 48, color: Color(0xFFE5E5EA)),
                  _buildActionRow(
                    icon: CupertinoIcons.bag_fill,
                    iconColor: const Color(0xFF34C759),
                    title: 'Purchase History',
                    subtitle: 'Receipts and payment status for orders',
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const PurchaseHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // 5. Section: Account Settings
                _buildSectionHeader('ACCOUNT & SECURITY'),
                const SizedBox(height: 8),
                _buildGroupedCard([
                  _buildActionRow(
                    icon: CupertinoIcons.person_crop_circle,
                    iconColor: const Color(0xFF007AFF),
                    title: 'Edit Profile',
                    subtitle: 'Update your name, city and contact details',
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) =>
                              EditProfileScreen(userData: user),
                        ),
                      );
                      if (updated == true) {
                        _loadUserProfile();
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 48, color: Color(0xFFE5E5EA)),
                  _buildActionRow(
                    icon: CupertinoIcons.lock_shield_fill,
                    iconColor: const Color(0xFFFF9500),
                    title: 'Change Password',
                    subtitle: 'Secure and update your account password',
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 48, color: Color(0xFFE5E5EA)),
                  _buildActionRow(
                    icon: CupertinoIcons.share,
                    iconColor: const Color(0xFF34C759),
                    title: 'Share App',
                    subtitle: 'Invite friends and fellow students to prepare',
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text:
                              '📚 Prepare for exams with Olive Learnings! Visit: https://eduapp.hkrdn.in',
                        ),
                      );
                      _showIosToast(
                        title: 'App Link Copied',
                        message: 'Share link copied to clipboard.',
                        icon: CupertinoIcons.link,
                        iconColor: const Color(0xFF007AFF),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // 6. Section: Sign Out
                _buildGroupedCard([
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    onPressed: _handleLogout,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.square_arrow_left,
                          color: Color(0xFFFF3B30),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 28),

                // 7. App Version Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Olive Learnings',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version 1.0.0 (Build 1)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== User Summary Card ====================
  Widget _buildUserHeaderCard({
    required String name,
    required String email,
    required String phone,
    required String role,
  }) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(18),
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
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Apple Style Squircle Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User Name & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF5FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== iOS Section Header ====================
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ==================== iOS Inset Grouped Card ====================
  Widget _buildGroupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E5EA),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // ==================== Detail Row ====================
  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 17,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Action Row ====================
  Widget _buildActionRow({
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: iconColor,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
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
              'Could Not Load Profile',
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
              onPressed: _loadUserProfile,
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

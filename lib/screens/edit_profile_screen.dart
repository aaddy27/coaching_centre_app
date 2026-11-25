import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({
    super.key,
    required this.userData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userData['name']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userData['email']?.toString() ?? '',
    );
    _cityController = TextEditingController(
      text: widget.userData['city']?.toString() ?? '',
    );
    _stateController = TextEditingController(
      text: widget.userData['state']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        showIosToast(
          context,
          title: 'Profile Updated',
          message: response['message'] ?? 'Your details have been saved.',
        );
        Navigator.pop(context, true);
      } else {
        showIosToast(
          context,
          title: 'Update Failed',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Could not update profile.',
          ),
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: IosTheme.systemRed,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userData['name']?.toString() ?? 'S';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    final phone = widget.userData['phone']?.toString() ?? '';

    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: const IosNavBar(title: 'Edit Profile'),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: IosTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const IosSectionLabel('Personal Details'),
                  IosGroupedCard(
                    children: [
                      _buildFormRow(
                        icon: CupertinoIcons.person_fill,
                        iconColor: IosTheme.primaryBlue,
                        controller: _nameController,
                        hint: 'Full Name',
                        validator: (v) {
                          if (v == null || v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const Divider(
                        height: 0.5,
                        indent: 48,
                        color: IosTheme.separator,
                      ),
                      _buildFormRow(
                        icon: CupertinoIcons.mail_solid,
                        iconColor: IosTheme.systemIndigo,
                        controller: _emailController,
                        hint: 'Email Address',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null &&
                              v.trim().isNotEmpty &&
                              !v.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const Divider(
                        height: 0.5,
                        indent: 48,
                        color: IosTheme.separator,
                      ),
                      _buildFormRow(
                        icon: CupertinoIcons.building_2_fill,
                        iconColor: IosTheme.systemOrange,
                        controller: _cityController,
                        hint: 'City',
                      ),
                      const Divider(
                        height: 0.5,
                        indent: 48,
                        color: IosTheme.separator,
                      ),
                      _buildFormRow(
                        icon: CupertinoIcons.map_pin_ellipse,
                        iconColor: IosTheme.systemPurple,
                        controller: _stateController,
                        hint: 'State',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const IosSectionLabel('Registered Mobile'),
                  IosGroupedCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: IosTheme.systemGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                CupertinoIcons.phone_fill,
                                size: 16,
                                color: IosTheme.systemGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Mobile',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: IosTheme.labelPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              phone.isNotEmpty ? '+91 $phone' : 'Not set',
                              style: const TextStyle(
                                fontSize: 15,
                                color: IosTheme.labelTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 6),
                    child: Text(
                      'Registered mobile number is verified via OTP and cannot be changed here.',
                      style: TextStyle(
                        fontSize: 12,
                        color: IosTheme.labelTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  IosPrimaryButton(
                    label: 'Save Changes',
                    isLoading: _isLoading,
                    onPressed: _handleUpdateProfile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormRow({
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(
                fontSize: 15.5,
                color: IosTheme.labelPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: IosTheme.labelTertiary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}

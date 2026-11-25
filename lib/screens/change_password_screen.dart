import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.changePassword(
        currentPassword: _currentPasswordController.text,
        password: _newPasswordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        showIosToast(
          context,
          title: 'Password Changed',
          message: response['message'] ?? 'Password updated successfully.',
        );
        Navigator.pop(context);
      } else {
        showIosToast(
          context,
          title: 'Update Failed',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Could not change password.',
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
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: const IosNavBar(title: 'Change Password'),
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
                  const IosSectionLabel('Password Details'),
                  IosGroupedCard(
                    children: [
                      _buildPasswordRow(
                        controller: _currentPasswordController,
                        hint: 'Current Password',
                        obscure: _obscureCurrent,
                        onToggle: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter your current password';
                          }
                          return null;
                        },
                      ),
                      const Divider(
                        height: 0.5,
                        indent: 48,
                        color: IosTheme.separator,
                      ),
                      _buildPasswordRow(
                        controller: _newPasswordController,
                        hint: 'New Password (min 6 characters)',
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return 'Must be at least 6 characters';
                          }
                          if (v == _currentPasswordController.text) {
                            return 'Must differ from current password';
                          }
                          return null;
                        },
                      ),
                      const Divider(
                        height: 0.5,
                        indent: 48,
                        color: IosTheme.separator,
                      ),
                      _buildPasswordRow(
                        controller: _confirmPasswordController,
                        hint: 'Confirm New Password',
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 8),
                    child: Text(
                      'Use a strong password of at least 6 characters. Other sessions may be signed out for security.',
                      style: TextStyle(
                        fontSize: 12,
                        color: IosTheme.labelTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  IosPrimaryButton(
                    label: 'Update Password',
                    isLoading: _isLoading,
                    onPressed: _handleChangePassword,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRow({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.lock_fill,
            size: 18,
            color: IosTheme.labelTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
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
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            onPressed: onToggle,
            child: Icon(
              obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              size: 19,
              color: IosTheme.labelTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

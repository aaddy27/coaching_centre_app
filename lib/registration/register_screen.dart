import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main_screen.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';
import '../widgets/ios_otp_input.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isResending = false;
  bool _isOtpStep = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendRegistrationOtp({bool isResend = false}) async {
    if (!isResend && !_formKey.currentState!.validate()) return;

    setState(() {
      if (isResend) {
        _isResending = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final response = await ApiService.register(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _isOtpStep = true;
          _otpController.clear();
        });
        showIosToast(
          context,
          title: 'OTP Sent',
          message: response['message'] ??
              '6-digit OTP sent to your mobile number.',
          icon: CupertinoIcons.chat_bubble_text_fill,
          iconColor: IosTheme.primaryBlue,
        );
      } else {
        showIosToast(
          context,
          title: 'Registration Error',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Could not start registration.',
          ),
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: IosTheme.systemRed,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isResending = false;
        });
      }
    }
  }

  Future<void> _verifyRegistrationOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      showIosToast(
        context,
        title: 'Invalid OTP',
        message: 'Please enter the 6-digit code sent via SMS.',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: IosTheme.systemOrange,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.verifyRegistrationOtp(
        phone: _phoneController.text.trim(),
        otp: otp,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data']?['token'] != null) {
        await ApiService.saveToken(response['data']['token'].toString());
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        await _showSuccessSheet();
      } else {
        showIosToast(
          context,
          title: 'Verification Failed',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Invalid or expired OTP.',
          ),
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: IosTheme.systemRed,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessSheet() async {
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Icon(
            CupertinoIcons.checkmark_seal_fill,
            color: IosTheme.systemGreen,
            size: 46,
          ),
        ),
        content: const Column(
          children: [
            Text(
              'Account Created!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Welcome to Olive Learnings. Your account is ready.',
              style: TextStyle(fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Start Learning'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      CupertinoPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(
        title: _isOtpStep ? 'Verify Mobile' : 'Create Account',
        onBack: _isOtpStep
            ? () => setState(() => _isOtpStep = false)
            : () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _isOtpStep ? _buildOtpStep() : _buildFormStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Join Olive Learnings',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: IosTheme.labelPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your details to receive a 6-digit verification OTP.',
            style: TextStyle(
              fontSize: 14,
              color: IosTheme.labelTertiary,
            ),
          ),
          const SizedBox(height: 22),

          const IosSectionLabel('Student Information'),
          IosGroupedCard(
            children: [
              // Full Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.person_fill,
                      size: 19,
                      color: IosTheme.labelTertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          fontSize: 16,
                          color: IosTheme.labelPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Full Name',
                          hintStyle: TextStyle(color: IosTheme.labelTertiary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0.5, indent: 14, color: IosTheme.separator),
              // Phone Number
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: IosTheme.groupedBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: IosTheme.labelPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontSize: 16,
                          color: IosTheme.labelPrimary,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          hintText: '10-digit mobile number',
                          hintStyle: TextStyle(color: IosTheme.labelTertiary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Enter your mobile number';
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                            return 'Enter a valid 10-digit number (6-9)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const IosSectionLabel('Set Password'),
          IosGroupedCard(
            children: [
              // Password
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.lock_fill,
                      size: 19,
                      color: IosTheme.labelTertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          fontSize: 16,
                          color: IosTheme.labelPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Password (min 6 characters)',
                          hintStyle: TextStyle(color: IosTheme.labelTertiary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      child: Icon(
                        _obscurePassword
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        size: 20,
                        color: IosTheme.labelTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0.5, indent: 14, color: IosTheme.separator),
              // Confirm Password
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.lock_shield_fill,
                      size: 19,
                      color: IosTheme.labelTertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(
                          fontSize: 16,
                          color: IosTheme.labelPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Confirm Password',
                          hintStyle: TextStyle(color: IosTheme.labelTertiary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword,
                        );
                      },
                      child: Icon(
                        _obscureConfirmPassword
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        size: 20,
                        color: IosTheme.labelTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          IosPrimaryButton(
            label: 'Continue & Send OTP',
            isLoading: _isLoading,
            onPressed: () => _sendRegistrationOtp(),
          ),
          const SizedBox(height: 18),

          Center(
            child: CupertinoButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Already have an account? Sign In',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: IosTheme.primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: IosTheme.systemGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              CupertinoIcons.checkmark_shield_fill,
              size: 34,
              color: IosTheme.systemGreen,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Enter Verification Code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: IosTheme.labelPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'We sent a 6-digit SMS code via MSG91 to verify your account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: IosTheme.labelTertiary,
          ),
        ),
        const SizedBox(height: 24),

        IosOtpInput(
          controller: _otpController,
          phone: _phoneController.text.trim(),
          isResending: _isResending,
          onResend: () => _sendRegistrationOtp(isResend: true),
          onCompleted: (_) {
            if (!_isLoading) _verifyRegistrationOtp();
          },
        ),
        const SizedBox(height: 26),

        IosPrimaryButton(
          label: 'Verify & Create Account',
          isLoading: _isLoading,
          color: IosTheme.systemGreen,
          onPressed: _verifyRegistrationOtp,
        ),
        const SizedBox(height: 12),
        Center(
          child: CupertinoButton(
            onPressed: () => setState(() => _isOtpStep = false),
            child: const Text(
              'Edit Phone Number',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: IosTheme.primaryBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

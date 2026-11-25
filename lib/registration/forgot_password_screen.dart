import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';
import '../widgets/ios_otp_input.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isResending = false;

  // Steps: 0 = phone, 1 = 6-digit otp, 2 = new password
  int _step = 0;
  String? _resetToken;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      showIosToast(
        context,
        title: 'Invalid Mobile Number',
        message: 'Enter a valid 10-digit Indian mobile number starting with 6-9.',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: IosTheme.systemOrange,
      );
      return;
    }

    setState(() {
      if (isResend) {
        _isResending = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final response = await ApiService.forgotPassword(phone: phone);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _step = 1;
          _otpController.clear();
        });
        showIosToast(
          context,
          title: 'Reset OTP Sent',
          message: response['message'] ?? '6-digit OTP sent to your mobile.',
          icon: CupertinoIcons.chat_bubble_text_fill,
          iconColor: IosTheme.primaryBlue,
        );
      } else {
        showIosToast(
          context,
          title: 'Failed',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Could not send reset OTP.',
          ),
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: IosTheme.systemRed,
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

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      showIosToast(
        context,
        title: 'Enter 6-Digit OTP',
        message: 'Please enter all 6 digits of your reset OTP.',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: IosTheme.systemOrange,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.verifyOtp(
        phone: _phoneController.text.trim(),
        otp: otp,
      );
      if (!mounted) return;

      if (response['success'] == true) {
        final token = response['data']?['reset_token']?.toString() ??
            response['reset_token']?.toString();
        if (token != null && token.isNotEmpty) {
          setState(() {
            _resetToken = token;
            _step = 2;
          });
          showIosToast(
            context,
            title: 'OTP Verified',
            message: 'Now set a new password for your account.',
          );
          return;
        }
      }
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (pwd.length < 6) {
      showIosToast(
        context,
        title: 'Weak Password',
        message: 'Password must be at least 6 characters long.',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: IosTheme.systemOrange,
      );
      return;
    }

    if (pwd != confirm) {
      showIosToast(
        context,
        title: 'Mismatch',
        message: 'Passwords do not match.',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: IosTheme.systemOrange,
      );
      return;
    }

    if (_resetToken == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.resetPassword(
        phone: _phoneController.text.trim(),
        resetToken: _resetToken!,
        password: pwd,
        passwordConfirmation: confirm,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        HapticFeedback.mediumImpact();
        showIosToast(
          context,
          title: 'Password Updated',
          message: response['message'] ?? 'You can now sign in with your new password.',
        );
        Navigator.pushAndRemoveUntil(
          context,
          CupertinoPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        showIosToast(
          context,
          title: 'Reset Failed',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Could not reset password.',
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
      appBar: IosNavBar(
        title: 'Reset Password',
        onBack: _step > 0
            ? () => setState(() => _step--)
            : () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step Progress Pill Bar
                Row(
                  children: List.generate(3, (index) {
                    final active = index <= _step;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: active
                              ? IosTheme.primaryBlue
                              : IosTheme.separator,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: IosTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _step == 0
                          ? CupertinoIcons.device_phone_portrait
                          : (_step == 1
                              ? CupertinoIcons.chat_bubble_2_fill
                              : CupertinoIcons.lock_rotation),
                      size: 32,
                      color: IosTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _step == 0
                      ? 'Forgot Password?'
                      : (_step == 1 ? 'Verify Reset OTP' : 'Create New Password'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.labelPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == 0
                      ? 'Enter your registered mobile number to receive a 6-digit OTP.'
                      : (_step == 1
                          ? 'Enter the 6-digit verification code sent to your mobile.'
                          : 'Choose a strong password of at least 6 characters.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: IosTheme.labelTertiary,
                  ),
                ),
                const SizedBox(height: 26),

                if (_step == 0) _buildPhoneStep(),
                if (_step == 1) _buildOtpStep(),
                if (_step == 2) _buildPasswordStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IosSectionLabel('Registered Mobile Number'),
        IosGroupedCard(
          children: [
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
                    child: TextField(
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        IosPrimaryButton(
          label: 'Send Reset OTP',
          isLoading: _isLoading,
          onPressed: () => _sendOtp(),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosOtpInput(
          controller: _otpController,
          phone: _phoneController.text.trim(),
          isResending: _isResending,
          onResend: () => _sendOtp(isResend: true),
          onCompleted: (_) {
            if (!_isLoading) _verifyOtp();
          },
        ),
        const SizedBox(height: 24),
        IosPrimaryButton(
          label: 'Verify OTP',
          isLoading: _isLoading,
          onPressed: _verifyOtp,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IosSectionLabel('New Credentials'),
        IosGroupedCard(
          children: [
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
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        fontSize: 16,
                        color: IosTheme.labelPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'New Password',
                        hintStyle: TextStyle(color: IosTheme.labelTertiary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
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
                    child: TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(
                        fontSize: 16,
                        color: IosTheme.labelPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Confirm New Password',
                        hintStyle: TextStyle(color: IosTheme.labelTertiary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
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
        const SizedBox(height: 24),
        IosPrimaryButton(
          label: 'Reset Password',
          isLoading: _isLoading,
          color: IosTheme.systemGreen,
          onPressed: _resetPassword,
        ),
      ],
    );
  }
}

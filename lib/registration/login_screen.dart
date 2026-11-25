import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main_screen.dart';
import '../services/api_service.dart';
import '../widgets/ios_components.dart';
import '../widgets/ios_otp_input.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  // 0 = OTP Login (default passwordless), 1 = Password Login
  int _authMode = 0;
  bool _otpSent = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _isValidIndianPhone(String phone) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  void _completeSignIn(String message) {
    HapticFeedback.mediumImpact();
    showIosToast(
      context,
      title: 'Welcome Back',
      message: message,
      icon: CupertinoIcons.checkmark_alt_circle_fill,
      iconColor: IosTheme.systemGreen,
    );

    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.login(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data']?['token'] != null) {
        await ApiService.saveToken(response['data']['token'].toString());
        if (!mounted) return;
        _completeSignIn(response['message'] ?? 'Login successful!');
      } else {
        showIosToast(
          context,
          title: 'Sign In Failed',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Invalid phone number or password.',
          ),
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: IosTheme.systemRed,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRequestLoginOtp({bool isResend = false}) async {
    final phone = _phoneController.text.trim();
    if (!_isValidIndianPhone(phone)) {
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
      final response = await ApiService.requestLoginOtp(phone: phone);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _otpSent = true;
          _otpController.clear();
        });
        showIosToast(
          context,
          title: 'OTP Sent',
          message: response['message'] ??
              'Login OTP sent successfully to your mobile number.',
          icon: CupertinoIcons.chat_bubble_text_fill,
          iconColor: IosTheme.primaryBlue,
        );
      } else {
        showIosToast(
          context,
          title: 'Could Not Send OTP',
          message: ApiService.extractErrorMessage(
            response,
            fallback: 'Unable to send login OTP.',
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

  Future<void> _handleVerifyLoginOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      showIosToast(
        context,
        title: 'Enter 6-Digit OTP',
        message: 'Please enter the complete 6-digit verification code.',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: IosTheme.systemOrange,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.verifyLoginOtp(phone: phone, otp: otp);
      if (!mounted) return;

      if (response['success'] == true && response['data']?['token'] != null) {
        await ApiService.saveToken(response['data']['token'].toString());
        if (!mounted) return;
        _completeSignIn(response['message'] ?? 'Login successful!');
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

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: canPop
          ? const IosNavBar(title: 'Sign In')
          : null,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!canPop) const SizedBox(height: 16),

                  // App Squircle Monogram & Title
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: IosTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: IosTheme.primaryBlue.withValues(alpha: 0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.book_fill,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Olive Learnings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: IosTheme.labelPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to access your courses, videos & mock tests',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: IosTheme.labelTertiary,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Native iOS Segmented Control: OTP vs Password
                  CupertinoSlidingSegmentedControl<int>(
                    groupValue: _authMode,
                    backgroundColor: const Color(0xFFE3E3E8),
                    thumbColor: Colors.white,
                    padding: const EdgeInsets.all(3),
                    children: const {
                      0: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'OTP Login',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: IosTheme.labelPrimary,
                          ),
                        ),
                      ),
                      1: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: IosTheme.labelPrimary,
                          ),
                        ),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      HapticFeedback.selectionClick();
                      setState(() {
                        _authMode = value;
                        _otpSent = false;
                        _otpController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 22),

                  // Inset Grouped Form
                  const IosSectionLabel('Account Credentials'),
                  IosGroupedCard(
                    children: [
                      // Mobile Number Row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: IosTheme.groupedBg,
                                borderRadius: BorderRadius.circular(7),
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
                                enabled: !(_authMode == 0 && _otpSent),
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: IosTheme.labelPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: const InputDecoration(
                                  hintText: '10-digit mobile number',
                                  hintStyle: TextStyle(
                                    color: IosTheme.labelTertiary,
                                    fontWeight: FontWeight.normal,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) {
                                    return 'Enter your mobile number';
                                  }
                                  if (!_isValidIndianPhone(v)) {
                                    return 'Enter a valid 10-digit number (starts with 6-9)';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (_authMode == 0 && _otpSent)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(32, 32),
                                onPressed: () {
                                  setState(() {
                                    _otpSent = false;
                                    _otpController.clear();
                                  });
                                },
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: IosTheme.primaryBlue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Password Row (when Password mode active)
                      if (_authMode == 1) ...[
                        const Divider(
                          height: 0.5,
                          indent: 14,
                          color: IosTheme.separator,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
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
                                    hintText: 'Password',
                                    hintStyle: TextStyle(
                                      color: IosTheme.labelTertiary,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_authMode != 1) return null;
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
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
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
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
                      ],
                    ],
                  ),

                  // 6-Digit OTP Box when OTP Login Step 2
                  if (_authMode == 0 && _otpSent) ...[
                    const SizedBox(height: 22),
                    IosOtpInput(
                      controller: _otpController,
                      phone: _phoneController.text.trim(),
                      isResending: _isResending,
                      onResend: () => _handleRequestLoginOtp(isResend: true),
                      onCompleted: (_) {
                        if (!_isLoading) _handleVerifyLoginOtp();
                      },
                    ),
                  ],

                  // Forgot Password Link (Password Mode)
                  if (_authMode == 1) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: IosTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 20),

                  const SizedBox(height: 8),

                  // Primary CTA Button
                  IosPrimaryButton(
                    label: _authMode == 1
                        ? 'Sign In'
                        : (_otpSent ? 'Verify & Sign In' : 'Send Login OTP'),
                    isLoading: _isLoading,
                    onPressed: _authMode == 1
                        ? _handlePasswordLogin
                        : (_otpSent
                            ? _handleVerifyLoginOtp
                            : () => _handleRequestLoginOtp()),
                  ),

                  const SizedBox(height: 24),

                  // Secondary Actions Card
                  IosGroupedCard(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.person_add,
                              size: 18,
                              color: IosTheme.primaryBlue,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Create New Account',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: IosTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (!canPop) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: CupertinoButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const MainScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Continue as Guest',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: IosTheme.labelTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

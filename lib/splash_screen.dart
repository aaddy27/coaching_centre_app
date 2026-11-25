import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'registration/login_screen.dart';
import 'services/api_service.dart';
import 'widgets/ios_components.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final isLoggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (context) =>
            isLoggedIn ? const MainScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: IosTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: IosTheme.primaryBlue.withValues(alpha: 0.24),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.book_fill,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Olive Learnings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: IosTheme.labelPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Learn. Practice. Succeed.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: IosTheme.labelTertiary,
                ),
              ),
              const SizedBox(height: 44),
              const CupertinoActivityIndicator(radius: 13),
            ],
          ),
        ),
      ),
    );
  }
}

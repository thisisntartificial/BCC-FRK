import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'listening_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const ListeningScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hearing,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'ULTRASONIC',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'HEARING',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textSecondary,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Personal audio amplifier & analyzer',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

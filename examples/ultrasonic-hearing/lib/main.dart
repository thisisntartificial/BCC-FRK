import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UltraSonicApp());
}

class UltraSonicApp extends StatelessWidget {
  const UltraSonicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UltraSonic Hearing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), _goNext);
  }

  void _goNext() {
    final isDark = _settings.darkMode.value;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(darkMode: isDark)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/placeholder.png',
            width: 160,
            height: 160,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

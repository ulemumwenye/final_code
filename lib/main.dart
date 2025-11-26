import 'package:flutter/material.dart';
import 'package:secure_application/secure_application.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/simple_live_notification_service.dart'; // Use simple service
import 'services/settings_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize settings service (reads dark mode and font scale)
  await SettingsService().init();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SimpleLiveNotificationService _liveNotificationService;
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    // Initialize and start monitoring for live broadcasts
    _liveNotificationService = SimpleLiveNotificationService();
    _liveNotificationService.startMonitoring();
    // Listen for dark mode changes
    _settings.darkMode.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _liveNotificationService.dispose();
    _settings.darkMode.removeListener(_onSettingsChanged);
    super.dispose();
  }
  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SecureApplication(
      nativeRemoveDelay: 800,
      onNeedUnlock: (secureApplicationController) async {
        secureApplicationController?.authSuccess(unlock: true);
        return null;
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: _settings.darkMode,
        builder: (context, isDark, _) {
          return MaterialApp(
            title: 'Nation Online',
            theme: ThemeData.light().copyWith(
              primaryColor: Colors.blue,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: Colors.blue,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                elevation: 0,
              ),
            ),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: SecureGate(child: const SplashScreen()),
              // home: SecureGate(
              //   blurr: 20,
              //   opacity: 0.5,
              //   child: HomeScreen(darkMode: isDark),
              // ),
          );
        },
      ),
    );
  }
}
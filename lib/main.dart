import 'package:flutter/material.dart';
import 'package:secure_application/secure_application.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/simple_live_notification_service.dart'; // Use simple service

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final darkMode = preferences.getBool('darkMode') ?? false;

  runApp(MyApp(darkMode: darkMode));
}

class MyApp extends StatefulWidget {
  final bool darkMode;
  const MyApp({Key? key, required this.darkMode}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SimpleLiveNotificationService _liveNotificationService;

  @override
  void initState() {
    super.initState();
    // Initialize and start monitoring for live broadcasts
    _liveNotificationService = SimpleLiveNotificationService();
    _liveNotificationService.startMonitoring();
  }

  @override
  void dispose() {
    _liveNotificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SecureApplication(
      nativeRemoveDelay: 800,
      onNeedUnlock: (secureApplicationController) async {
        secureApplicationController?.authSuccess(unlock: true);
        return null;
      },
      child: MaterialApp(
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
        themeMode: widget.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: SecureGate(
          blurr: 20,
          opacity: 0.5,
          child: HomeScreen(darkMode: widget.darkMode),
        ),
      ),
    );
  }
}
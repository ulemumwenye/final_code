import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);
  final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> summarizeOnOpen = ValueNotifier<bool>(false);

  static const _keyDark = 'darkMode';
  static const _keyFont = 'fontScale';
  static const _keySummarize = 'summarizeOnOpen';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode.value = prefs.getBool(_keyDark) ?? false;
    fontScale.value = prefs.getDouble(_keyFont) ?? 1.0;
    summarizeOnOpen.value = prefs.getBool(_keySummarize) ?? false;
  }

  Future<void> setDarkMode(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDark, v);
    darkMode.value = v;
  }

  Future<void> setFontScale(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFont, v);
    fontScale.value = v;
  }

  Future<void> setSummarizeOnOpen(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySummarize, v);
    summarizeOnOpen.value = v;
  }
}

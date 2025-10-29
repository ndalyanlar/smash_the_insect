import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _soundEnabledKey = 'sound_enabled';
  static const String _musicEnabledKey = 'music_enabled';
  static const String _languageKey = 'language';

  // Varsayılan değerler
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  String _language =
      Platform.localeName.contains('tr') ? 'tr' : 'en'; //english varsayılan

  // Getters
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  String get language => _language;

  // Ayarları yükle
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
    _language = prefs.getString(_languageKey) ?? 'en';
  }

  // Ses ayarını kaydet
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }

  // Müzik ayarını kaydet
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, enabled);
  }

  // Dil ayarını kaydet
  Future<void> setLanguage(String language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  // Dil isimlerini al
  Map<String, String> get availableLanguages => {
        'tr': 'Türkçe',
        'en': 'English',
      };

  // Mevcut dilin ismini al
  String get currentLanguageName => availableLanguages[_language] ?? 'Türkçe';
}

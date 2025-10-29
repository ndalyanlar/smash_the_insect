import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'settings_service.dart';
import 'analytics_service.dart';
import 'sound_manager.dart';
import '../generated/locale_keys.g.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  final AnalyticsService _analytics = AnalyticsService();

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  String _selectedLanguage = 'tr';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _analytics.logCustomEvent(
      eventName: 'settings_screen_view',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  Future<void> _loadSettings() async {
    await _settings.loadSettings();
    setState(() {
      _soundEnabled = _settings.soundEnabled;
      _musicEnabled = _settings.musicEnabled;
      _selectedLanguage = _settings.language;
    });
  }

  Future<void> _saveSoundSetting(bool enabled) async {
    await _settings.setSoundEnabled(enabled);
    setState(() {
      _soundEnabled = enabled;
    });

    // Ses efektleri SoundManager'da zaten ayarlar üzerinden kontrol ediliyor
    // Sadece müzik ayarı değişmişse onu güncelle
    if (!enabled && _musicEnabled) {
      // Ses efektleri kapalı ama müzik açıksa, hiçbir şey yapma
      // Ses açıldığında müzik hala çalıyorsa devam edecek
    }

    _analytics.logCustomEvent(
      eventName: 'sound_setting_changed',
      parameters: {
        'enabled': enabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> _saveMusicSetting(bool enabled) async {
    await _settings.setMusicEnabled(enabled);
    setState(() {
      _musicEnabled = enabled;
    });

    // Müzik ayarını güncelle (SoundManager'da otomatik başlatılır/durdurulur)
    SoundManager.updateMusicSettings();

    _analytics.logCustomEvent(
      eventName: 'music_setting_changed',
      parameters: {
        'enabled': enabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> _saveLanguageSetting(String language) async {
    await _settings.setLanguage(language);
    setState(() {
      _selectedLanguage = language;
    });

    // Easy Localization ile dili değiştir
    await context.setLocale(Locale(language));

    _analytics.logCustomEvent(
      eventName: 'language_setting_changed',
      parameters: {
        'language': language,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF87CEEB), // Açık mavi (oyun teması ile aynı)
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.settings,
                        size: 60,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        LocaleKeys.settings_title.tr(),
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          shadows: [
                            const Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Ayarlar listesi
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Ses Ayarları Bölümü
                        _buildSectionTitle(LocaleKeys.sound_settings.tr()),
                        const SizedBox(height: 15),

                        // Ses Efektleri
                        _buildSwitchTile(
                          title: LocaleKeys.sound_effects.tr(),
                          subtitle: LocaleKeys.sound_effects_desc.tr(),
                          icon: Icons.volume_up,
                          value: _soundEnabled,
                          onChanged: _saveSoundSetting,
                        ),

                        const SizedBox(height: 15),

                        // Müzik
                        _buildSwitchTile(
                          title: LocaleKeys.music.tr(),
                          subtitle: LocaleKeys.music_desc.tr(),
                          icon: Icons.music_note,
                          value: _musicEnabled,
                          onChanged: _saveMusicSetting,
                        ),

                        const SizedBox(height: 30),

                        // Dil Ayarları Bölümü
                        _buildSectionTitle(LocaleKeys.language_settings.tr()),
                        const SizedBox(height: 15),

                        // Dil Seçimi
                        _buildLanguageSelector(),

                        // Test Butonu
                        // _buildTestButton(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Versiyon ve Uygulama Bilgileri
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Versiyon 1.0.0 (Build 1)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Geri dön butonu
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57), // Deniz yeşili
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.arrow_back,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          LocaleKeys.back_to_home_settings.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2E8B57),
            activeTrackColor: Colors.white.withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.7),
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.language,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.language.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _settings.currentLanguageName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: _selectedLanguage,
            dropdownColor: const Color(0xFF2E8B57),
            borderRadius: BorderRadius.circular(15),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            underline: Container(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 28,
            ),
            iconSize: 28,
            items: _settings.availableLanguages.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: Colors.white.withOpacity(0.9),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            selectedItemBuilder: (BuildContext context) {
              return _settings.availableLanguages.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            onChanged: (String? newValue) {
              if (newValue != null) {
                _saveLanguageSetting(newValue);
              }
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flame_audio/flame_audio.dart';
import 'settings_service.dart';

class SoundManager {
  static final SettingsService _settings = SettingsService();
  static AudioPlayer? _backgroundMusicPlayer;

  // Düşman öldürme sesi (smash.wav)
  static Future<void> playSmashSound() async {
    if (_settings.soundEnabled) {
      try {
        await FlameAudio.play('smash.wav', volume: 0.5);
      } catch (e) {
        print('Smash sound error: $e');
      }
    }
  }

  // Hasar alma sesi
  static Future<void> playDamageSound() async {
    if (_settings.soundEnabled) {
      try {
        // Hasar için hafif bir "thud" sesi (smash'in daha hafif versiyonu)
        await FlameAudio.play('smash.wav', volume: 0.3);
      } catch (e) {
        print('Damage sound error: $e');
      }
    }
  }

  // Arka plan müziği başlat
  static Future<void> startBackgroundMusic() async {
    print('Attempting to start background music...');
    print('Music enabled: ${_settings.musicEnabled}');

    if (_settings.musicEnabled) {
      try {
        stopBackgroundMusic(); // Önce mevcut müziği durdur

        // AudioPlayer oluştur
        _backgroundMusicPlayer = AudioPlayer();

        // Ses dosyasını yükle ve çal - loop otomatik çalışmıyor, elle yapmalıyız
        await _backgroundMusicPlayer!
            .play(AssetSource('audio/background_sound.wav'));
        await _backgroundMusicPlayer!.setReleaseMode(ReleaseMode.loop);
        await _backgroundMusicPlayer!.setVolume(0.4);

        print('Background music started successfully with looping');
      } catch (e) {
        print('Background music error: $e');
      }
    } else {
      print('Music is disabled in settings');
    }
  }

  // Arka plan müziğini durdur
  static Future<void> stopBackgroundMusic() async {
    try {
      if (_backgroundMusicPlayer != null) {
        await _backgroundMusicPlayer!.stop();
        _backgroundMusicPlayer = null;
        print('Background music stopped');
      }
    } catch (e) {
      print('Stop background music error: $e');
    }
  }

  // Arka plan müziğini duraklat
  static Future<void> pauseBackgroundMusic() async {
    try {
      if (_backgroundMusicPlayer != null) {
        await _backgroundMusicPlayer!.pause();
        print('Background music paused');
      }
    } catch (e) {
      print('Pause background music error: $e');
    }
  }

  // Arka plan müziğini devam ettir
  static Future<void> resumeBackgroundMusic() async {
    if (_settings.musicEnabled) {
      try {
        if (_backgroundMusicPlayer != null) {
          await _backgroundMusicPlayer!.resume();
          print('Background music resumed');
        } else {
          // Eğer müzik yoksa başlat
          startBackgroundMusic();
        }
      } catch (e) {
        print('Resume background music error: $e');
      }
    }
  }

  // Ayarlar değiştiğinde müziği güncelle
  static Future<void> updateMusicSettings() async {
    if (!_settings.musicEnabled) {
      await stopBackgroundMusic();
    } else {
      // Eğer müzik kapalıysa ve açıldıysa başlat
      if (_backgroundMusicPlayer == null) {
        await startBackgroundMusic();
      }
    }
  }

  // Müzik durumunu kontrol et
  static bool get isMusicPlaying => _backgroundMusicPlayer != null;

  // Ayarları yükle (başlangıç için)
  static Future<void> loadSettings() async {
    await _settings.loadSettings();
  }
}

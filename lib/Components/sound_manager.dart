import 'package:flame_audio/flame_audio.dart';

class SoundManager {
  static bool _isEnabled = true;

  // Ses efektleri
  static Future<void> playHitSound() async {
    if (_isEnabled) {
      try {
        await FlameAudio.play('hit.mp3', volume: 0.5);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static Future<void> playExplosionSound() async {
    if (_isEnabled) {
      try {
        await FlameAudio.play('explosion.mp3', volume: 0.7);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static Future<void> playHealSound() async {
    if (_isEnabled) {
      try {
        await FlameAudio.play('heal.mp3', volume: 0.4);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static Future<void> playComboSound() async {
    if (_isEnabled) {
      try {
        await FlameAudio.play('combo.mp3', volume: 0.6);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static Future<void> playPowerUpSound() async {
    if (_isEnabled) {
      try {
        await FlameAudio.play('powerup.mp3', volume: 0.5);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static Future<void> playDamageSound() async {
    if (_isEnabled) {
      try {
        await FlameAudio.play('damage.mp3', volume: 0.6);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static Future<void> playGameOverSound() async {
    if (_isEnabled) {
      try {
        await FlameAudio.play('gameover.mp3', volume: 0.8);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static Future<void> playBackgroundMusic() async {
    if (_isEnabled) {
      try {
        await FlameAudio.playLongAudio('background.mp3', volume: 0.3);
      } catch (e) {
        // Ses dosyası yoksa sessizce devam et
      }
    }
  }

  static void toggleSound() {
    _isEnabled = !_isEnabled;
    // Ses efektleri zaten _isEnabled kontrolü ile durduruluyor
    // Yeni sesler çalmayacak, mevcut sesler doğal olarak bitecek
  }

  static bool get isEnabled => _isEnabled;
}

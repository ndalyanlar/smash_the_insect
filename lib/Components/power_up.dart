import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';
import 'Util/state.dart';
import 'sound_manager.dart';

enum PowerUpType {
  health,
  speed,
  shield,
  multiHit,
  freeze,
  bomb,
}

class PowerUp extends PositionComponent with KnowsGameSize {
  final PowerUpType type;
  final GameController gameController;
  late Timer _lifeTimer;
  bool _isCollected = false;
  bool get isCollected => _isCollected;

  PowerUp({
    required this.type,
    required this.gameController,
    Vector2? position,
    Vector2? size,
  }) : super(
          position: position ?? Vector2.zero(),
          size: size ?? Vector2.all(50),
        ) {
    // Anchor'u center yap ki position center olsun (dokunma kontrolü için)
    anchor = Anchor.center;
    // 3-4 saniye arasında rastgele yaşam süresi
    final lifeSeconds = 3.0 + (Random().nextDouble() * 1.0); // 3.0-4.0 saniye
    _lifeTimer = Timer(lifeSeconds, onTick: () {
      // Süre dolduğunda kaybolsun (patlamasın)
      _isCollected = true;
      removeFromParent();
    });
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _lifeTimer.start();
    // Effect'ler PositionComponent ile çalışmıyor, render'da manuel animasyon yapıyoruz
  }

  @override
  void render(Canvas canvas) {
    if (_isCollected) return;

    // Sprite null olduğu için manuel render yapıyoruz
    // super.render() çağırmıyoruz çünkü sprite yok

    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final pulse = (sin(time * 4.0) + 1) / 2;

    final center = Offset(size.x / 2, size.y / 2);
    final baseRadius = size.x / 2;

    // Ana daire (power-up'ın kendisi) - sprite yerine renkli daire
    final mainColor = _getColorForType();
    final mainPaint = Paint()..color = mainColor.withValues(alpha: 0.9);
    canvas.drawCircle(center, baseRadius - 3, mainPaint);

    // Dış glow efekti
    final glowPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.4 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, baseRadius + 8 * pulse, glowPaint);

    // İç halka (parıltı efekti)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, baseRadius - 5, ringPaint);

    // Tip ikonu (emoji)
    _drawEmojiIcon(canvas, center, baseRadius);
  }

  void _drawEmojiIcon(Canvas canvas, Offset center, double radius) {
    final emoji = _emojiForType();
    final text = TextPaint(
      style: TextStyle(
        fontSize: radius * 1.2,
      ),
    );
    text.render(
      canvas,
      emoji,
      Vector2(center.dx, center.dy),
      anchor: Anchor.center,
    );
  }

  String _emojiForType() {
    switch (type) {
      case PowerUpType.health:
        return "❤️";
      case PowerUpType.speed:
        return "⚡️";
      case PowerUpType.shield:
        return "🛡️";
      case PowerUpType.multiHit:
        return "✴️";
      case PowerUpType.freeze:
        return "❄️";
      case PowerUpType.bomb:
        return "💣";
    }
  }

  Color _getColorForType() {
    switch (type) {
      case PowerUpType.health:
        return Colors.red;
      case PowerUpType.speed:
        return Colors.blue;
      case PowerUpType.shield:
        return Colors.cyan;
      case PowerUpType.multiHit:
        return Colors.purple;
      case PowerUpType.freeze:
        return Colors.lightBlue;
      case PowerUpType.bomb:
        return Colors.orange;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifeTimer.update(dt);
    // Otomatik toplama kaldırıldı - sadece dokunmayla aktif olacak
  }

  // Dokunma ile toplama (game_controller'dan çağrılacak)
  void collect() {
    if (_isCollected) return;
    _isCollected = true;

    // Power-up etkisini uygula
    _applyEffect();
    SoundManager.playSmashSound();

    // Hemen kaldır (effect yerine direkt kaldırıyoruz)
    removeFromParent();
  }

  void _applyEffect() {
    switch (type) {
      case PowerUpType.health:
        gameController.player.currentHealth =
            (gameController.player.currentHealth + 20).clamp(0, 100);
        gameController.player.currentHealth =
            (gameController.player.currentHealth + 20).clamp(0, 100);
        break;
      case PowerUpType.speed:
        // Dokunma yarıçapı büyüsün (geçici hız buff hissi)
        gameController.activateSpeedBoost(durationSeconds: 8);
        break;
      case PowerUpType.shield:
        gameController.activateShield(durationSeconds: 6);
        break;
      case PowerUpType.multiHit:
        // Skor çarpanı 2x (geçici)
        gameController.activateMultiHit(durationSeconds: 10);
        break;
      case PowerUpType.freeze:
        // Düşmanları dondur
        gameController.activateFreeze(durationSeconds: 4);
        break;
      case PowerUpType.bomb:
        // Ekrandaki tüm küçük düşmanları yok et
        gameController.triggerBomb();
        break;
    }
  }
}

class PowerUpManager extends Component with KnowsGameSize {
  final GameController gameController;
  late Timer _spawnTimer;
  final Random _random = Random();
  List<PowerUp> powerUps = [];
  int _spawnAttempts = 0; // Spawn deneme sayısı

  PowerUpManager({required this.gameController}) : super() {
    // Başlangıçta seviye/spawn hızına göre dinamik interval kullan
    _spawnTimer =
        Timer(_computeSpawnInterval(), onTick: _spawnPowerUp, repeat: true);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _spawnTimer.start();
    if (kDebugMode) {
      print(
          "🚀 PowerUpManager başlatıldı - İlk spawn: ${_computeSpawnInterval().toStringAsFixed(1)}s");
    }
  }

  // Seviye ve spawn hızına göre power-up spawn aralığını günceller
  void updateSpawnRate() {
    _spawnTimer.stop();
    _spawnTimer =
        Timer(_computeSpawnInterval(), onTick: _spawnPowerUp, repeat: true);
    _spawnTimer.start();
  }

  double _computeSpawnInterval() {
    // Level'e göre spawn hızını artır
    final level = gameController.currentLevel;
    final m = gameController.spawnRateMultiplier.clamp(1.0, 3.0);

    // Temel süre 15s
    var baseInterval = 15.0;

    // Level'e göre interval azaltma (her level için %8-10 daha hızlı)
    // İlk 10 level için hızlı azalma, sonrası yavaş azalma
    double levelReduction;
    if (level <= 10) {
      levelReduction = (level - 1) * 0.08; // Her level için %8 azalma
    } else {
      // İlk 10 level'daki azalma + sonraki level'lar için ek azalma
      const baseReduction = 9 * 0.08; // İlk 10 level'daki toplam azalma
      final additionalLevels = level - 10;
      levelReduction = baseReduction +
          (additionalLevels * 0.03); // Sonraki level'lar için %3 azalma
    }

    // Level azalmasını uygula
    baseInterval = baseInterval *
        (1.0 - levelReduction.clamp(0.0, 0.75)); // Max %75 azalma

    // Spawn rate multiplier'ı da uygula
    final interval = baseInterval / (1.0 + (m - 1.0) * 0.5);

    // Minimum 3s, maksimum 15s
    return interval.clamp(3.0, 15.0);
  }

  void _spawnPowerUp() {
    // GameState kontrolü
    if (gameController.gameState != GameState.playing) return;

    // GameSize kontrolü - eğer henüz set edilmemişse gameController.size kullan
    final effectiveGameSize =
        gameSize.x > 0 && gameSize.y > 0 ? gameSize : gameController.size;

    if (effectiveGameSize.x <= 0 || effectiveGameSize.y <= 0) {
      if (kDebugMode) {
        print("⚠️ PowerUp spawn: gameSize henüz hazır değil");
      }
      return;
    }

    // Seviye ile olasılığı artır ve ilk 3 spawn'ı garantile
    final level = gameController.currentLevel;
    _spawnAttempts++;

    // İlk 3 denemeyi garantile, sonrası yüksek olasılık
    final baseChance = _spawnAttempts <= 3 ? 1.0 : 0.85 + (level * 0.01);
    final chance =
        baseChance.clamp(0.85, 0.95); // %85-95 arası garantili yüksek şans

    if (kDebugMode) {
      print(
          "🎁 PowerUp spawn denemesi - Level: $level, Attempt: $_spawnAttempts, Chance: ${(chance * 100).toStringAsFixed(1)}%");
    }

    if (_random.nextDouble() < chance) {
      final type =
          PowerUpType.values[_random.nextInt(PowerUpType.values.length)];

      // Rastgele pozisyon - ekranın içinde kal
      const margin = 50.0;
      final x =
          margin + _random.nextDouble() * (effectiveGameSize.x - 2 * margin);
      final y =
          margin + _random.nextDouble() * (effectiveGameSize.y - 2 * margin);

      final powerUp = PowerUp(
        type: type,
        gameController: gameController,
        position: Vector2(x, y),
        size: Vector2.all(50), // Daha büyük boyut
      );

      powerUps.add(powerUp);
      add(powerUp);
      if (kDebugMode) {
        print(
            "✅ PowerUp spawn edildi: ${type.toString().split('.').last} at ($x, $y)");
      }
    } else {
      if (kDebugMode) {
        print("❌ PowerUp spawn başarısız (rastgele)");
      }
    }
  }

  // _getSpriteForType artık gerekli değil - render'da manuel çiziyoruz

  @override
  void update(double dt) {
    super.update(dt);
    _spawnTimer.update(dt);

    // Toplanan/ölü power-up'ları temizle
    powerUps.removeWhere((powerUp) {
      // Sadece gerçekten kaldırılmış veya toplanmış olanları sil
      if (powerUp.isCollected) return true;
      // isMounted kısa bir an false olabilir; hemen silmeyelim
      if (powerUp.isRemoving || powerUp.isRemoved) return true;
      return false;
    });
  }

  @override
  void onRemove() {
    super.onRemove();
    _spawnTimer.stop();
  }
}

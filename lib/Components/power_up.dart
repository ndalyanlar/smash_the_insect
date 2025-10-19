import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';
import 'sound_manager.dart';

enum PowerUpType {
  health,
  speed,
  shield,
  multiHit,
}

class PowerUp extends SpriteComponent with KnowsGameSize {
  final PowerUpType type;
  final GameController gameController;
  late Timer _lifeTimer;
  bool _isCollected = false;

  PowerUp({
    required this.type,
    required this.gameController,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
  }) : super(sprite: sprite, position: position, size: size) {
    _lifeTimer = Timer(10.0, onTick: () {
      removeFromParent();
    });
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _lifeTimer.start();

    // Power-up animasyonu: parıldama efekti
    add(SequenceEffect([
      ScaleEffect.by(
        Vector2.all(0.1),
        EffectController(duration: 0.5),
      ),
      ScaleEffect.by(
        Vector2.all(-0.1),
        EffectController(duration: 0.5),
      ),
    ], repeatCount: -1));

    // Renk değişimi efekti
    add(SequenceEffect([
      ColorEffect(
        const Color(0xFFFFD700),
        EffectController(duration: 0.3),
      ),
      ColorEffect(
        const Color(0xFFFFFFFF),
        EffectController(duration: 0.3),
      ),
    ], repeatCount: -1));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifeTimer.update(dt);

    // Oyuncuya yaklaşma efekti
    if (!_isCollected &&
        position.distanceTo(gameController.player.position) < 100) {
      position.moveToTarget(gameController.player.position, 200 * dt);
    }

    // Toplama kontrolü
    if (!_isCollected &&
        position.distanceTo(gameController.player.position) < 30) {
      _collect();
    }
  }

  void _collect() {
    if (_isCollected) return;
    _isCollected = true;

    // Toplama efekti
    add(SequenceEffect([
      ScaleEffect.by(
        Vector2.all(0.5),
        EffectController(duration: 0.2),
      ),
      OpacityEffect.to(
        0.0,
        EffectController(duration: 0.1),
      ),
    ], onComplete: () {
      if (parent != null) {
        removeFromParent();
      }
    }));

    // Power-up etkisini uygula
    _applyEffect();
    SoundManager.playPowerUpSound();
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
        // Hız artışı (geçici)
        break;
      case PowerUpType.shield:
        // Kalkan efekti (geçici)
        break;
      case PowerUpType.multiHit:
        // Çoklu vuruş efekti (geçici)
        break;
    }
  }
}

class PowerUpManager extends Component with KnowsGameSize {
  final GameController gameController;
  late Timer _spawnTimer;
  final Random _random = Random();

  PowerUpManager({required this.gameController}) : super() {
    _spawnTimer = Timer(15.0, onTick: _spawnPowerUp, repeat: true);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _spawnTimer.start();
  }

  void _spawnPowerUp() {
    // Skora göre spawn olasılığı
    if (_random.nextDouble() < 0.3) {
      final type =
          PowerUpType.values[_random.nextInt(PowerUpType.values.length)];

      // Rastgele pozisyon
      final x = _random.nextDouble() * gameSize.x;
      final y = _random.nextDouble() * gameSize.y;

      final powerUp = PowerUp(
        type: type,
        gameController: gameController,
        sprite: _getSpriteForType(type),
        position: Vector2(x, y),
        size: Vector2.all(40),
      );

      add(powerUp);
    }
  }

  Sprite _getSpriteForType(PowerUpType type) {
    // Burada farklı power-up türleri için sprite'lar döndürülebilir
    // Şimdilik varsayılan sprite kullanıyoruz
    return Sprite(gameController.images.fromCache("cake.png"));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spawnTimer.update(dt);
  }

  @override
  void onRemove() {
    super.onRemove();
    _spawnTimer.stop();
  }
}

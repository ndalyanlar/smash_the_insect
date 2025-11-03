import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';
import 'Util/state.dart';
import 'enemy.dart';

class EnemyManager extends Component with KnowsGameSize {
  late Timer _spawnTimer;
  List<Sprite> sprites;
  final GameController gameController;
  List<Enemy> enemies = [];
  final Random _random = Random();
  final int maxComboEnemies = 4; // Ekranda maksimum kombo düşman

  EnemyManager({required this.sprites, required this.gameController})
      : super() {
    _spawnTimer = Timer(2.0, onTick: _spawnEnemy, repeat: true);
  }

  // Spawn timer'ı level'e göre güncelle
  void updateSpawnRate() {
    // Level arttıkça spawn hızını daha agresif artır
    final level = gameController.currentLevel;
    final baseSpawnTime = 2.0;

    // Level'e göre spawn zamanını daha hızlı yap
    final levelBonus =
        1.0 - (level - 1) * 0.05; // Her level için %5 daha hızlı (min %50)
    final adjustedSpawnTime = baseSpawnTime * levelBonus.clamp(0.5, 1.0);

    // Ayrıca spawnRateMultiplier'ı da uygula
    final newSpawnTime = adjustedSpawnTime / gameController.spawnRateMultiplier;

    _spawnTimer.stop();
    _spawnTimer = Timer(newSpawnTime, onTick: _spawnEnemy, repeat: true);
    _spawnTimer.start();
  }

  void _spawnEnemy() {
    if (gameController.gameState != GameState.playing) return;

    // Maksimum düşman sayısı: level * 0.5 (minimum 5)
    final currentLevel = gameController.currentLevel;
    final maxEnemies = (currentLevel * 0.5).round().clamp(5, 30);
    if (enemies.length >= maxEnemies) return;

    // Level 3'ten sonra kombo düşmanlar spawn olabilir
    final canSpawnCombo = currentLevel >= 3;

    // Kombo düşman spawn şansı: Level 3-5 arası düşük, sonrası daha sık
    double comboChance = 0.0;
    if (canSpawnCombo) {
      if (currentLevel <= 5) {
        comboChance = 0.2; // Level 3-5: %20
      } else if (currentLevel <= 10) {
        comboChance = 0.35; // Level 6-10: %35
      } else {
        comboChance = 0.5; // Level 10+: %50
      }
    }

    // Ekrandaki mevcut kombo sayısını kontrol et ve sınırla
    final currentComboCount =
        enemies.where((e) => e.isComboEnemy && !e.isDead).length;
    bool isComboEnemy = canSpawnCombo && _random.nextDouble() < comboChance;
    if (currentComboCount >= maxComboEnemies) {
      isComboEnemy = false; // Kombo sınırı doluysa küçük düşman üret
    }
    final comboMultiplier = isComboEnemy ? 5 : 1;

    if (isComboEnemy) {
      if (kDebugMode) {
        print("🎯 Level $currentLevel'da KOMBO DÜŞMAN SPAWN EDİLİYOR!");
      }
    }

    // Rastgele sprite seç
    final sprite = sprites[_random.nextInt(sprites.length)];

    // Ekranın kenarından spawn et
    final side = _random.nextInt(4); // 0: üst, 1: sağ, 2: alt, 3: sol
    Vector2 position;

    switch (side) {
      case 0: // Üst
        position = Vector2(_random.nextDouble() * gameSize.x, -50);
        break;
      case 1: // Sağ
        position = Vector2(gameSize.x + 50, _random.nextDouble() * gameSize.y);
        break;
      case 2: // Alt
        position = Vector2(_random.nextDouble() * gameSize.x, gameSize.y + 50);
        break;
      case 3: // Sol
        position = Vector2(-50, _random.nextDouble() * gameSize.y);
        break;
      default:
        position = Vector2.zero();
    }

    // Düşman oluştur
    // Minimal ölçek için daha küçük boyutlar
    final enemy = Enemy(
      gameController: gameController,
      sprite: sprite,
      position: position,
      size: isComboEnemy
          ? Vector2(85 * gameController.uiScale, 85 * gameController.uiScale)
          : Vector2(50 * gameController.uiScale, 50 * gameController.uiScale),
      isComboEnemy: isComboEnemy,
      comboMultiplier: comboMultiplier,
    );

    enemies.add(enemy);
    add(enemy);

    if (kDebugMode) {
      print(
          "Düşman spawn edildi: ${enemies.length} ${isComboEnemy ? '(Kombo!)' : ''}");
    }

    // Küçük düşmanları seviye arttıkça daha sık üret: ekstra spawn denemesi
    if (!isComboEnemy && enemies.length < maxEnemies) {
      final extraChance =
          (currentLevel * 0.05).clamp(0.0, 0.5); // seviye ile %0-%50
      if (_random.nextDouble() < extraChance) {
        _spawnSmallEnemy(maxEnemies);
      }
    }
  }

  void _spawnSmallEnemy(int maxEnemies) {
    if (enemies.length >= maxEnemies) return;

    // Rastgele sprite seç
    final sprite = sprites[_random.nextInt(sprites.length)];

    // Ekranın kenarından spawn et
    final side = _random.nextInt(4); // 0: üst, 1: sağ, 2: alt, 3: sol
    Vector2 position;

    switch (side) {
      case 0: // Üst
        position = Vector2(_random.nextDouble() * gameSize.x, -50);
        break;
      case 1: // Sağ
        position = Vector2(gameSize.x + 50, _random.nextDouble() * gameSize.y);
        break;
      case 2: // Alt
        position = Vector2(_random.nextDouble() * gameSize.x, gameSize.y + 50);
        break;
      case 3: // Sol
        position = Vector2(-50, _random.nextDouble() * gameSize.y);
        break;
      default:
        position = Vector2.zero();
    }

    final enemy = Enemy(
      gameController: gameController,
      sprite: sprite,
      position: position,
      size: Vector2(50 * gameController.uiScale, 50 * gameController.uiScale),
      isComboEnemy: false,
      comboMultiplier: 1,
    );

    enemies.add(enemy);
    add(enemy);
  }

  @override
  void onMount() {
    super.onMount();
    _spawnTimer.start();
  }

  @override
  void onRemove() {
    super.onRemove();
    _spawnTimer.stop();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spawnTimer.update(dt);

    // Ölü düşmanları temizle
    enemies.removeWhere((enemy) {
      if (enemy.isDead) {
        enemy.removeFromParent();
        return true;
      }
      return false;
    });
  }
}

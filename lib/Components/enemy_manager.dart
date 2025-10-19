import 'dart:math';
import 'package:flame/components.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';
import 'Util/state.dart';
import 'enemy.dart';

class EnemyManager extends Component with KnowsGameSize {
  late Timer _spawnTimer;
  List<Sprite> sprites;
  final GameController gameController;
  List<Enemy> enemies = [];

  EnemyManager({required this.sprites, required this.gameController})
      : super() {
    _spawnTimer = Timer(2.0, onTick: _spawnEnemy, repeat: true);
  }

  // Spawn timer'ı level'e göre güncelle
  void updateSpawnRate() {
    final baseSpawnTime = 2.0;
    final newSpawnTime = baseSpawnTime / gameController.spawnRateMultiplier;
    _spawnTimer.stop();
    _spawnTimer = Timer(newSpawnTime, onTick: _spawnEnemy, repeat: true);
    _spawnTimer.start();
  }

  void _spawnEnemy() {
    if (gameController.gameState != GameState.playing) return;

    // Maksimum 10 düşman
    if (enemies.length >= 10) return;

    // Rastgele sprite seç
    final sprite = sprites[Random().nextInt(sprites.length)];

    // Ekranın kenarından spawn et
    final side = Random().nextInt(4); // 0: üst, 1: sağ, 2: alt, 3: sol
    Vector2 position;

    switch (side) {
      case 0: // Üst
        position = Vector2(Random().nextDouble() * gameSize.x, -50);
        break;
      case 1: // Sağ
        position = Vector2(gameSize.x + 50, Random().nextDouble() * gameSize.y);
        break;
      case 2: // Alt
        position = Vector2(Random().nextDouble() * gameSize.x, gameSize.y + 50);
        break;
      case 3: // Sol
        position = Vector2(-50, Random().nextDouble() * gameSize.y);
        break;
      default:
        position = Vector2.zero();
    }

    // Düşman oluştur
    final enemy = Enemy(
      gameController: gameController,
      sprite: sprite,
      position: position,
      size: Vector2(50, 50),
    );

    enemies.add(enemy);
    add(enemy);

    print("Düşman spawn edildi: ${enemies.length}");
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

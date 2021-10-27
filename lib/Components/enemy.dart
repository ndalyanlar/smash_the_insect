import 'package:flame/components.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';

class Enemy extends SpriteComponent with KnowsGameSize {
  bool isDead = false;
  int health = 1;
  bool isPressed = false;
  final GameController gameController;
  Enemy(
    this.gameController, {
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
  }) : super(sprite: sprite, position: position, size: size);

  @override
  void update(double dt) {
    super.update(dt);

    gameController.score % 15 == 0 && gameController.score != 0
        ? {
            gameController.enemyManager.speed += 0.2,
          }
        : null;
    double stepDistance = gameController.enemyManager.speed * dt;

    !isPressed
        ? position.moveToTarget(gameController.player.position, stepDistance)
        : null;

    if (isPressed) {
      gameController.score = (gameController.score + 1.0 / 2);
    }
  }
}

enum EnemyType { boss, chimp }

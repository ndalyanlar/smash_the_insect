import 'dart:math';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';
import 'enemy.dart';

class EnemyManager extends Component with KnowsGameSize {
  late Timer _timer;
  double speed = 100;
  List<Sprite> sprites;
  late Map<Enemy, Enemy> enemyList;
  EnemyType enemyType = EnemyType.chimp;
  Random random = Random();
  late Enemy enemy;
  late Enemy explosion;
  final GameController gameController;
  EnemyManager({required this.sprites, required this.gameController})
      : super() {
    _timer = Timer(1, callback: spawnerEnemy, repeat: true);
    enemyList = {};
  }

  void spawnerEnemy() {
    var angle = random.nextInt(360).toDouble();
    double radius = getRadius;

    enemy = Enemy(
      gameController,
      sprite: sprites[0],
    );

    explosion = Enemy(
      gameController,
      sprite: sprites[1],
    );

    double x = gameSize.toSize().width / 2 + radius * cos(angle);
    double y = gameSize.toSize().height / 2 + radius * sin(angle);

    x = getX(x);
    y = getY(y);

    Vector2 initialSize = Vector2(64, 64);

    Rect positionRect = Rect.fromLTWH(
        x, y, initialSize.toRect().width, initialSize.toRect().height);
    Vector2 position = Vector2(positionRect.center.dx, positionRect.center.dy);

    explosion.angle = Vector2(x, y).toOffset().direction;

    enemy.anchor = Anchor.center;
    enemy.position = position;
    enemy.size = initialSize;

    explosion.anchor = Anchor.center;
    explosion.position = position;
    explosion.size = initialSize;

    enemyList[enemy] = explosion;

    explosion.setOpacity(0);

    add(explosion);
    add(enemy);
  }

  @override
  void onMount() {
    super.onMount();
    _timer.start();
  }

  @override
  void onRemove() {
    super.onRemove();
    _timer.stop();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer.update(dt);
  }

  double get getRadius =>
      math.sqrt((gameSize.toSize().width / 2 * gameSize.toSize().width / 2 +
          gameSize.toSize().height / 2 * gameSize.toSize().height / 2));

  double getX(double x) => x < 0 ? x - 100 : x + 100;

  double getY(double y) => y < 0 ? y - 100 : y + 100;
}

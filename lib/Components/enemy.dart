import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';

class Enemy extends SpriteComponent with KnowsGameSize {
  final GameController gameController;
  bool isDead = false;
  double speed = 50.0; // Hareket hızı

  Enemy({
    required this.gameController,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
  }) : super(sprite: sprite, position: position, size: size) {
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isDead) return;

    // Pastaya doğru hareket et (level hızı ile)
    final direction = (gameController.player.position - position).normalized();
    final currentSpeed = speed * gameController.enemySpeedMultiplier;
    position += direction * currentSpeed * dt;
  }
}
